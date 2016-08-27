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

      @doc """
      Runs an operation's process/1 function after a contract's validation
      """
      @spec run(Keyword.t | Map.t) :: Validation.validation_error | any
      @spec run :: Validation.validation_error | any
      def run(received_params \\ []) do
        params = resolve_defaults(@contract, received_params, received_params)

        case validation_result = Validation.valid?(@contract, params) do
          :ok ->
            process(params)
          _ ->
            validation_result
        end
      end

      @spec resolve_defaults(list(%{name: atom, opts: Keyword.t}), Keyword.t | Map.t, Keyword.t | Map.t) :: Keyword.t | Map.t
      defp resolve_defaults([], _received_params, resolved_params), do: resolved_params
      defp resolve_defaults([%{name: contract_item_name, opts: contract_item_opts} | contract_tail], received_params, resolved_params) do
        resolved_params =
          with true <- Keyword.has_key?(contract_item_opts, :default),
            nil <- Exop.ValidationChecks.get_check_item(received_params, contract_item_name) do
              default_value = Keyword.get(contract_item_opts, :default)
              # don't know at this moment whether resolved_params were provided as Map or Keyword
              cond do
                is_map(resolved_params) ->
                  Map.put(resolved_params, contract_item_name, default_value)
                is_list(resolved_params) ->
                  Keyword.put(resolved_params, contract_item_name, default_value)
                true ->
                  resolved_params
              end
            else
              _ ->
                resolved_params
            end

        resolve_defaults(contract_tail, received_params, resolved_params)
      end
    end
  end

  @spec parameter(atom, Keyword.t) :: none
  defmacro parameter(name, opts \\ []) when is_atom(name) do
    quote bind_quoted: [name: name, opts: opts] do
      @contract %{name: name, opts: opts}
    end
  end
end
