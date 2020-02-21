defmodule Exop.Chain do
  @moduledoc """
  Provides macros to organize a number of Exop.Operation modules into an invocation chain.

  ## Example

      defmodule CreateUser do
        use Exop.Chain

        alias Operations.{User, Backoffice, Notifications}

        operation User.Create
        operation Backoffice.SaveStats
        operation Notifications.SendEmail
      end

      # CreateUser.run(name: "User Name", age: 37, gender: "m")

  `Exop.Chain` defines `run/1` function that takes `keyword()` or `map()` of params.
  Those params will be passed into the first operation in the chain.
  Bear in mind that each of chained operations (except the first one) awaits a returned result of
  a previous operation as incoming params.

  So in the example above `CreateUser.run(name: "User Name", age: 37, gender: "m")` will invoke
  the chain by passing `[name: "User Name", age: 37, gender: "m"]` params to the first `User.Create`
  operation.
  The result of `User.Create` operation will be passed to `Backoffice.SaveStats`
  operation as its params and so on.

  Once any of operations in the chain returns non-ok-tuple result (error result, interruption, auth error etc.)
  the chain execution interrupts and error result returned (as the chain (`CreateUser`) result).
  """

  defmacro __using__(opts \\ []) do
    quote do
      import unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :operations, accumulate: true)

      @error_includes_operation_name unquote(opts)[:name_in_error] == true

      @before_compile unquote(__MODULE__)
    end
  end

  @doc "Defines one of a chain's operation."
  @spec operation(module(), keyword()) :: any()
  defmacro operation(operation, opts \\ []) do
    quote bind_quoted: [operation: operation, opts: opts] do
      {:module, operation} = Code.ensure_compiled(operation)
      additional_params = Keyword.drop(opts, [:if])

      @operations %{
        operation: operation,
        additional_params: additional_params,
        if: Keyword.get(opts, :if)
      }
    end
  end

  @doc "Defines one of a chain's operation."
  @spec step(module(), keyword()) :: any()
  defmacro step(operation, opts \\ []) do
    quote bind_quoted: [operation: operation, opts: opts] do
      {:module, operation} = Code.ensure_compiled(operation)
      additional_params = Keyword.drop(opts, [:if])

      @operations %{
        operation: operation,
        additional_params: additional_params,
        if: Keyword.get(opts, :if, :no_if_condition)
      }
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      alias Exop.Validation

      @type interrupt_result :: {:interrupt, any}
      @type auth_result :: :ok | no_return
      #  throws:
      #  {:error, {:auth, :undefined_policy}} |
      #  {:error, {:auth, :unknown_policy}}   |
      #  {:error, {:auth, :unknown_action}}   |
      #  {:error, {:auth, atom}}

      @not_ok :exop_not_ok

      @doc """
      Invokes all operations defined in a chain. Returns either a result of the last operation
      in the chain or the first result that differs from ok-tuple (validation error, for example).
      """
      @spec run(Keyword.t() | map() | nil) ::
              {:ok, any} | Validation.validation_error() | interrupt_result | auth_result
      def run(received_params) do
        try do
          ok_result = @operations |> Enum.reverse() |> invoke_operations({:ok, received_params})
          {:ok, ok_result}
        catch
          {@not_ok, not_ok_result, operation} ->
            add_operation_name(@error_includes_operation_name, not_ok_result, operation)

          {@not_ok, not_ok_result} ->
            not_ok_result
        end
      end

      defp add_operation_name(true, not_ok_result, operation), do: {operation, not_ok_result}
      defp add_operation_name(_, not_ok_result, _), do: not_ok_result

      @spec invoke_operations([%{operation: atom(), additional_params: Keyword.t()}], any()) ::
              any()
      defp invoke_operations([], result) do
        result
      end

      defp invoke_operations(
             [
               %{operation: operation, additional_params: additional_params, if: if_condition}
               | tail
             ],
             {:ok, params} = _previous_result
           )
           when is_function(if_condition) do
        if if_condition.(params) == true do
          params = params |> merge_params(additional_params) |> resolve_params_values()
          invoke_operation(operation, tail, params)
        else
          # if it is the last operation in a chain and it has 'if' condition
          # and that condition is not applicable
          if length(tail) == 1 do
            params
          else
            invoke_operations(tail, params)
          end
        end
      end

      defp invoke_operations(
             [%{operation: operation, additional_params: additional_params} | tail],
             {:ok, params} = _previous_result
           ) do
        params = params |> merge_params(additional_params) |> resolve_params_values()
        invoke_operation(operation, tail, params)
      end

      defp invoke_operations(_operations, not_ok = _result) do
        throw({@not_ok, not_ok})
        @not_ok
      end

      @spec invoke_operation(map(), list(), map() | Keyword.t()) :: any()
      defp invoke_operation(operation, tail, params) do
        case apply(operation, :run, [params]) do
          result when is_tuple(result) and elem(result, 0) == :error ->
            throw({@not_ok, result, operation})
            @not_ok

          {:ok, _} = result ->
            if length(tail) > 0, do: invoke_operations(tail, result), else: elem(result, 1)

          result ->
            throw({@not_ok, result})
            @not_ok
        end
      end

      @spec merge_params(map() | keyword(), map() | keyword()) :: map()
      defp merge_params(params, additional_params)
           when is_map(params) and is_map(additional_params) do
        Map.merge(params, additional_params)
      end

      defp merge_params(params, additional_params)
           when is_list(params) and is_map(additional_params) do
        params |> Enum.into(%{}) |> Map.merge(additional_params)
      end

      defp merge_params(params, additional_params)
           when is_map(params) and is_list(additional_params) do
        Map.merge(params, Enum.into(additional_params, %{}))
      end

      defp merge_params(params, additional_params)
           when is_list(params) and is_list(additional_params) do
        params |> Enum.into(%{}) |> Map.merge(Enum.into(additional_params, %{}))
      end

      @spec resolve_params_values(map()) :: map()
      defp resolve_params_values(params) do
        Enum.reduce(params, %{}, fn {k, v}, acc ->
          v = if is_function(v), do: v.(), else: v
          Map.put(acc, k, v)
        end)
      end
    end
  end
end
