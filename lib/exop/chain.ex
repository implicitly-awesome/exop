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

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :operations, accumulate: true)

      @before_compile unquote(__MODULE__)
    end
  end

  defmacro operation(operation, additional_params \\ []) do
    quote bind_quoted: [operation: operation, additional_params: additional_params] do
      {:module, operation} = Code.ensure_compiled(operation)
      @operations %{operation: operation, additional_params: additional_params}
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

      @not_ok :not_ok

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
          {@not_ok, not_ok_result} -> not_ok_result
        end
      end

      @spec invoke_operations([%{operation: atom(), additional_params: Keyword.t()}], any()) ::
              any()
      defp invoke_operations([], result) do
        result
      end

      defp invoke_operations(
             [%{operation: operation, additional_params: additional_params} | []],
             {:ok, params} = _result
           ) do
        params = params |> merge_params(additional_params) |> resolve_params_values()

        with {:ok, result} <- apply(operation, :run, [params]) do
          result
        else
          not_ok ->
            throw({@not_ok, not_ok})
            @not_ok
        end
      end

      defp invoke_operations(
             [%{operation: operation, additional_params: additional_params} | tail],
             {:ok, params} = _result
           ) do
        params = params |> merge_params(additional_params) |> resolve_params_values()

        with {:ok, _} = result <- apply(operation, :run, [params]) do
          invoke_operations(tail, result)
        else
          not_ok ->
            throw({@not_ok, not_ok})
            @not_ok
        end
      end

      defp invoke_operations(_operations, not_ok = _result) do
        throw({@not_ok, not_ok})
        @not_ok
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
