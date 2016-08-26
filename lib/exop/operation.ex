defmodule Exop.Operation do
  @moduledoc """
  Provides macros for an operation's contract definition and process/1 function.

  ## Example

      defmodule SomeOperation do
        use Exop.Operation

        parameter :param1, type: :integer, required: true
        parameter :param2, type: :string, length: %{max: 3}, format: ~r/foo/

        def process(params) do
          "This is the operation's result with one of the params = " <> params[:param1]
        end
      end
  """

  alias Exop.Validation

  @callback process(Keyword.t | Map.t) :: any

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :contract, accumulate: true)

      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      alias Exop.Validation

      @spec contract :: list(Map.t)
      def contract do
        @contract
      end

      @spec run(Keyword.t | Map.t) :: Validation.validation_error | any
      @spec run :: Validation.validation_error | any
      def run(received_params \\ []) do
        case validation_result = Validation.valid?(@contract, received_params) do
          :ok ->
            Exop.Operation.Delegator.delegate(__MODULE__, :process, received_params)
          _ ->
            validation_result
        end
      end
    end
  end

  defmacro parameter(name, opts \\ []) when is_atom(name) do
    quote bind_quoted: [name: name, opts: opts] do
      @contract %{name: name, opts: opts}
    end
  end
end

defmodule Exop.Operation.Delegator do
  def delegate(module, function_name, params) do
    apply(module, function_name, [params])
  end
end
