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

  @type interrupt_result :: {:interrupt, any}
  @type auth_result :: :ok |
                       {:error, {:auth, :undefined_user}} |
                       {:error, {:auth, :undefined_policy}} |
                       {:error, {:auth, :undefined_action}} |
                       {:error, {:auth, atom}}

  @doc """
  Operation's entry point. Takes defined contract as the single parameter.
  Contract itself is a `Keyword.t` list: `[param_name: param_value]`
  """
  @callback process(map()) :: {:ok, any} |
                              Validation.validation_error |
                              interrupt_result |
                              auth_result

  defmacro __using__(_opts) do
    quote do
      require Logger

      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :contract, accumulate: true)
      Module.register_attribute(__MODULE__, :policy_module, [])
      Module.register_attribute(__MODULE__, :policy_action_name, [])

      @module_name __MODULE__

      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      alias Exop.Validation

      @type interrupt_result :: {:interrupt, any}
      @type auth_result :: :ok |
                           {:error, {:auth, :undefined_user}}   |
                           {:error, {:auth, :undefined_policy}} |
                           {:error, {:auth, :unknown_policy}}   |
                           {:error, {:auth, :unknown_action}}   |
                           {:error, {:auth, atom}}

      @exop_interruption :exop_interruption
      @exop_auth_error :exop_auth_error

      @spec contract :: list(map())
      def contract do
        @contract
      end

      @doc """
      Runs an operation's process/1 function after a contract validation
      """
      @spec run(Keyword.t | map() | nil) :: {:ok, any} | Validation.validation_error | interrupt_result | auth_result
      def run(received_params \\ [])
      def run(received_params) when is_list(received_params) do
        if Enum.uniq(Keyword.keys(received_params)) == Keyword.keys(received_params) do
          params = received_params |> resolve_defaults(@contract, received_params)
          params |> resolve_coercions(@contract, params) |> output
        else
          {:error, {:validation, %{params: "There are duplicates in received params list"}}}
        end
      end
      def run(received_params) when is_map(received_params) do
        received_params
        |> resolve_defaults(@contract, received_params)
        |> output
      end

      @spec run!(Keyword.t | map() | nil) :: any | RuntimeError
      def run!(received_params \\ []) do
        case run(received_params) do
          {:ok, result} ->
            result
          {:error, {:validation, reasons}} ->
            raise(Validation.ValidationError, Validation.errors_message(reasons))
          result ->
            result
        end
      end

      @spec resolve_defaults(Keyword.t | map(), list(%{name: atom, opts: Keyword.t}), Keyword.t | map()) :: Keyword.t | map()
      defp resolve_defaults(_received_params, [], resolved_params), do: resolved_params
      defp resolve_defaults(received_params, [%{name: contract_item_name, opts: contract_item_opts} | contract_tail], resolved_params) do
        resolved_params =
          if Keyword.has_key?(contract_item_opts, :default) &&
             Exop.ValidationChecks.get_check_item(received_params, contract_item_name) == nil do
               contract_item_opts |> Keyword.get(:default) |> put_into_collection(resolved_params, contract_item_name)
          else
            resolved_params
          end

        resolve_defaults(received_params, contract_tail, resolved_params)
      end

      @spec resolve_coercions(Keyword.t | map(), list(%{name: atom, opts: Keyword.t}), Keyword.t | map()) :: Keyword.t | map()
      defp resolve_coercions(_received_params, [], coerced_params), do: coerced_params
      defp resolve_coercions(received_params, [%{name: contract_item_name, opts: contract_item_opts} | contract_tail], coerced_params) do
        coerced_params =
          if Keyword.has_key?(contract_item_opts, :coerce_with) do
            coerce_with = Keyword.get(contract_item_opts, :coerce_with)
            coerced_value = coerce_with.(Exop.ValidationChecks.get_check_item(coerced_params, contract_item_name))
            put_into_collection(coerced_value, coerced_params, contract_item_name)
          else
            coerced_params
          end

        resolve_coercions(received_params, contract_tail, coerced_params)
      end

      @spec put_into_collection(any, Keyword.t | map(), atom) :: Keyword.t | map()
      defp put_into_collection(value, collection, item_name) when is_map(collection) do
        Map.put(collection, item_name, value)
      end
      defp put_into_collection(value, collection, item_name) when is_list(collection) do
        Keyword.put(collection, item_name, value)
      end
      defp put_into_collection(_value, collection, _item_name), do: collection

      defp output(params) do
        output(params, Validation.valid?(@contract, params))
      end
      @spec output(Keyword.t | map(), :ok | {:error, {:validation, map()}}) :: {:ok, any} |
                                                                               Validation.validation_error |
                                                                               interrupt_result
      defp output(params, :ok = _validation_result) do
        try do
          result = params |> Enum.into(%{}) |> process()

          case result do
            {:error, reason} -> {:error, reason}
            {:ok, result} -> {:ok, result}
            _ -> {:ok, result}
          end
        catch
          {@exop_interruption, reason} -> {:interrupt, reason}
          {@exop_auth_error, reason} -> {:error, {:auth, reason}}
        end
      end
      defp output(_params, {:error, {:validation, errors}} = validation_result) do
        Logger.warn("#{@module_name} errors: \n#{Validation.errors_message(errors)}")
        validation_result
      end
      defp output(_params, validation_result) do
        validation_result
      end

      @spec defined_params(Keyword.t | map()) :: map()
      def defined_params(received_params) when is_list(received_params) do
        keys_to_filter = Keyword.keys(received_params) -- Enum.map(@contract, &(&1[:name]))
        received_params |> Keyword.drop(keys_to_filter) |> Enum.into(%{})
      end
      def defined_params(received_params) when is_map(received_params) do
        keys_to_filter = Map.keys(received_params) -- Enum.map(@contract, &(&1[:name]))
        Map.drop(received_params, keys_to_filter)
      end

      @spec interrupt(any) :: no_return
      def interrupt(reason \\ nil), do: throw({@exop_interruption, reason})

      @spec do_authorize(Exop.Policy.t, atom, any, Keyword.t) :: auth_result
      defp do_authorize(_policy, _action, nil, _opts), do: throw({@exop_auth_error, :undefined_user})
      defp do_authorize(nil, _action, _user, _opts), do: throw({@exop_auth_error, :undefined_policy})
      defp do_authorize(_policy, nil, _user, _opts), do: throw({@exop_auth_error, :undefined_action})
      defp do_authorize(policy, action, user, opts) do
        try do
          case apply(policy, :authorize, [action, user, opts]) do
            false -> throw({@exop_auth_error, action})
            true -> :ok
          end
        rescue
          UndefinedFunctionError -> throw({@exop_auth_error, :unknown_policy})
        end
      end
    end
  end

  @doc """
  Defines a parameter with `name` and `opts` in an operation contract.
  Options could include the parameter value checks and transformations (like coercion).

  ## Example
      parameter :some_param, type: :map, required: true

  ## Available checks are:

  #### type
  Checks whether a parameter's value is of declared type.
      parameter :some_param, type: :map

  #### required
  Checks the presence of a parameter in passed params collection.
      parameter :some_param, required: true

  #### default
  Checks if the parameter is missed and assigns default value to it if so.
      parameter :some_param, default: "default value"

  #### numericality
  Checks whether a parameter's value is a number and passes constraints (if constraints were defined).
      parameter :some_param, numericality: %{equal_to: 10, greater_than: 0,
                                             greater_than_or_equal_to: 10,
                                             less_than: 20,
                                             less_than_or_equal_to: 10}

  #### in
  Checks whether a parameter's value is within a given list.
      parameter :some_param, in: ~w(a b c)

  #### not_in
  Checks whether a parameter's value is not within a given list.
      parameter :some_param, not_in: ~w(a b c)

  #### format
  Checks wether parameter's value matches given regex.
      parameter :some_param, format: ~r/foo/

  #### length
  Checks the length of a parameter's value.
      parameter :some_param, length: %{min: 5, max: 10, is: 7, in: 5..8}

  #### inner
  Checks the inner of either Map or Keyword parameter.
      parameter :some_param, type: :map, inner: %{
        a: [type: :integer, required: true],
        b: [type: :string, length: %{min: 1, max: 6}]
      }

  #### struct
  Checks whether the given parameter is expected structure.
      parameter :some_param, struct: %SomeStruct{}

  #### func
  Checks whether an item is valid over custom validation function.
      parameter :some_param, func: &__MODULE__.your_validation/2

      def your_validation(_params, param), do: !is_nil(param)

  ## Coercion

  It is possible to coerce a parameter before the contract validation, all validation checks
  will be invoked on coerced parameter value.
  Since coercion changes a parameter before any validation has been invoked,
  default values are resolved (with `:default` option) before the coercion.
  The flow looks like: `Resolve param default value -> Coerce -> Validate coerced`

      parameter :some_param, default: 1, numericality: %{greater_than: 0}, coerce_with: &__MODULE__.coerce/1

      def coerce(x), do: x * 2

  _For more information and examples check out general Exop docs._
  """
  @spec parameter(atom, Keyword.t) :: no_return
  defmacro parameter(name, opts \\ []) when is_atom(name) do
    quote bind_quoted: [name: name, opts: opts] do
      @contract %{name: name, opts: opts}
    end
  end

  @doc """
  Defines a policy that will be used for authorizing the possibility of a user
  to invoke an operation.
      defmodule ReadOperation do
        use Exop.Operation

        policy MyPolicy, :read

        parameter :user, required: true, struct: %User{}

        def process(_params) do
          authorize(params[:user])
          # make some reading...
        end
      end

  A policy itself might be:
      defmodule MyPolicy do
        use Exop.Policy

        def read(_user, _opts), do: true

        def write(_user, _opts), do: false
      end
  """
  @spec policy(Exop.Policy.t, atom) :: no_return
  defmacro policy(policy_module, action_name) when is_atom(action_name) do
    quote bind_quoted: [policy_module: policy_module, action_name: action_name] do
      @policy_module policy_module
      @policy_action_name action_name
    end
  end

  @doc """
  Authorizes an action with predefined policy (see `policy` macro docs).
  If authorization fails, any code after (below) auth check will be postponed (an error `{:error, {:auth, _reason}}` will be returned immediately)
  """
  @spec authorize(any, Keyword.t | nil) :: auth_result
  defmacro authorize(user, opts \\ []) do
    quote bind_quoted: [user: user, opts: opts] do
      do_authorize(@policy_module, @policy_action_name, user, opts)
    end
  end

  @doc """
  Returns policy that was defined in an operation.
  """
  @spec current_policy :: {Exop.Policy.t, atom}
  defmacro current_policy do
    quote do
      {@policy_module, @policy_action_name}
    end
  end
end
