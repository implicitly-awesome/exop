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

  @doc """
  Operation's entry point. Takes defined contract as the single parameter.
  Contract itself is a `Keyword.t` list: `[param_name: param_value]`
  """
  @callback process(map()) ::
              {:ok, any}
              | Validation.validation_error()
              | {:interrupt, any}
              | :ok
              | no_return

  defmacro __using__(_opts) do
    quote do
      require Logger

      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :contract, accumulate: true)

      @policy_module nil
      @policy_action_name nil
      @fallback_module nil
      @module_name __MODULE__

      @before_compile unquote(__MODULE__)
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

      @exop_interruption :exop_interruption
      @exop_auth_error :exop_auth_error

      @spec contract :: list(map())
      def contract do
        @contract
      end

      @doc """
      Runs an operation's process/1 function after a contract validation
      """
      @spec run(Keyword.t() | map() | nil) ::
              {:ok, any} | Validation.validation_error() | interrupt_result | auth_result
      def run(received_params \\ %{})

      def run(received_params) when is_list(received_params) do
        received_params |> Enum.into(%{}) |> run()
      end

      def run(received_params) when is_map(received_params) do
        params = resolve_defaults(received_params, @contract, received_params)
        result = params |> resolve_coercions(@contract, params) |> output()

        with {:ok, _} = result <- result do
          result
        else
          error -> invoke_fallback(@fallback_module, received_params, error)
        end
      end

      @spec invoke_fallback(map() | nil, map(), any()) :: any()
      defp invoke_fallback(%{module: fallback_module, opts: opts}, received_params, error) do
        fallback_result = apply(fallback_module, :process, [@module_name, received_params, error])

        if is_list(opts) && opts[:return], do: fallback_result, else: error
      end

      defp invoke_fallback(_fallback_module, _received_params, error), do: error

      @spec run!(Keyword.t() | map() | nil) :: any() | RuntimeError
      def run!(received_params \\ %{}) do
        case run(received_params) do
          {:ok, result} ->
            result

          {:error, {:validation, reasons}} ->
            raise(Validation.ValidationError, Validation.errors_message(reasons))

          result ->
            result
        end
      end

      @spec resolve_defaults(
              Keyword.t() | map(),
              list(%{name: atom, opts: Keyword.t()}),
              Keyword.t() | map()
            ) :: Keyword.t() | map()
      defp resolve_defaults(_received_params, [], resolved_params), do: resolved_params

      defp resolve_defaults(
             received_params,
             [%{name: contract_item_name, opts: contract_item_opts} | contract_tail],
             resolved_params
           ) do
        resolved_params =
          if Keyword.has_key?(contract_item_opts, :default) &&
               Exop.ValidationChecks.get_check_item(received_params, contract_item_name) == nil do
            contract_item_opts
            |> Keyword.get(:default)
            |> put_into_collection(resolved_params, contract_item_name)
          else
            resolved_params
          end

        resolve_defaults(received_params, contract_tail, resolved_params)
      end

      @spec resolve_coercions(
              Keyword.t() | map(),
              list(%{name: atom, opts: Keyword.t()}),
              Keyword.t() | map()
            ) :: Keyword.t() | map()
      defp resolve_coercions(_received_params, [], coerced_params), do: coerced_params

      defp resolve_coercions(
             received_params,
             [%{name: contract_item_name, opts: contract_item_opts} | contract_tail],
             coerced_params
           ) do
        coerced_params =
          if Keyword.has_key?(contract_item_opts, :coerce_with) do
            coerce_with = Keyword.get(contract_item_opts, :coerce_with)

            coerced_value =
              coerce_with.(Exop.ValidationChecks.get_check_item(coerced_params, contract_item_name))

            put_into_collection(coerced_value, coerced_params, contract_item_name)
          else
            coerced_params
          end

        resolve_coercions(received_params, contract_tail, coerced_params)
      end

      @spec put_into_collection(any, Keyword.t() | map(), atom) :: Keyword.t() | map()
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

      @spec output(Keyword.t() | map(), :ok | {:error, {:validation, map()}}) ::
              {:ok, any}
              | Validation.validation_error()
              | interrupt_result
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

      @spec defined_params(Keyword.t() | map()) :: map()
      def defined_params(received_params) when is_list(received_params) do
        keys_to_filter = Keyword.keys(received_params) -- Enum.map(@contract, & &1[:name])
        received_params |> Keyword.drop(keys_to_filter) |> Enum.into(%{})
      end

      def defined_params(received_params) when is_map(received_params) do
        keys_to_filter = Map.keys(received_params) -- Enum.map(@contract, & &1[:name])
        Map.drop(received_params, keys_to_filter)
      end

      @spec interrupt(any) :: :ok
      def interrupt(reason \\ nil) do
        throw({@exop_interruption, reason})
        :ok
      end

      @spec do_authorize(Exop.Policy.t(), atom, Keyword.t()) :: auth_result
      defp do_authorize(nil, _action, _opts) do
        throw({@exop_auth_error, :undefined_policy})
      end

      defp do_authorize(_policy, nil, _opts) do
        throw({@exop_auth_error, :undefined_action})
      end

      defp do_authorize(policy, action, opts) do
        try do
          case apply(policy, :authorize, [action, opts]) do
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

  #### list_item
  Checks whether each of list items conforms defined checks. An item's checks could be any that Exop offers:
      parameter :list_param, list_item: %{type: :string, length: %{min: 7}}

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
  defmacro authorize(opts \\ []) do
    quote bind_quoted: [opts: opts] do
      do_authorize(@policy_module, @policy_action_name, opts)
    end
  end

  @doc """
  Returns policy that was defined in an operation.
  """
  defmacro current_policy do
    quote do
      {@policy_module, @policy_action_name}
    end
  end

  @doc """
  Defines a fallback module that will be used for an operation's non-ok-tuple (fail) result handling.
      defmodule MultiplyByTenOperation do
        use Exop.Operation

        fallback LoggerFallback

        parameter :a, type: :integer, required: true

        def process(%{a: a}), do: a * 10
      end

  A fallback module itself might be:
      defmodule LoggerFallback do
        use Exop.Fallback
        require Logger

        def process(operation_module, params_passed_to_the_operation, operation_error_result) do
          Logger.error("Oops")
        end
      end

  If `return: true` option is provided then failed operation's `run/1` will return the
  fallback's `process/3` result.
  """
  defmacro fallback(fallback_module, opts \\ []) do
    quote bind_quoted: [fallback_module: fallback_module, opts: opts] do
      if Code.ensure_compiled?(fallback_module) && function_exported?(fallback_module, :process, 3) do
        @fallback_module %{module: fallback_module, opts: opts}
      else
        Logger.warn("#{@module_name}: #{fallback_module}.run/1 wasn't found")
        @fallback_module nil
      end
    end
  end
end
