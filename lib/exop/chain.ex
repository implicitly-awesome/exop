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

  defmacro operation(operation, opts \\ []) do
    quote bind_quoted: [operation: operation, opts: opts] do
      {:module, operation} = Code.ensure_compiled(operation)
      @operations %{operation: operation, opts: opts}
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
          @operations |> Enum.reverse() |> invoke_operations({:ok, received_params})
        catch
          {@not_ok, not_ok} -> not_ok
        end
      end

      @spec invoke_operations([%{operation: atom(), opts: Keyword.t()}], any()) :: any()
      defp invoke_operations([], result) do
        result
      end

      defp invoke_operations([%{operation: operation, opts: opts} | []], {:ok, params} = _result) do
        with {:ok, result} <- apply(operation, :run, [params]) do
          result
        else
          not_ok ->
            throw({@not_ok, not_ok})
            :not_ok
        end
      end

      defp invoke_operations([%{operation: operation, opts: opts} | tail], {:ok, params} = _result) do
        with {:ok, _} = result <- apply(operation, :run, [params]) do
          invoke_operations(tail, result)
        else
          not_ok ->
            throw({@not_ok, not_ok})
            :not_ok
        end
      end

      defp invoke_operations(_operations, not_ok = _result) do
        throw({@not_ok, not_ok})
        :not_ok
      end
    end
  end
end
