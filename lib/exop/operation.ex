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

  alias Exop.{Validation, TypeValidation}

  defmodule ErrorResult do
    defexception message: "Operation execution error"
  end

  @doc """
  Operation's entry point. Takes defined contract as the single parameter.
  Contract itself is a list of maps: `[%{name: atom(), opts: keyword()}]`
  """
  @callback process(map()) ::
              {:ok, any}
              | Validation.validation_error()
              | {:interrupt, any}
              | {:error, any}
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
    quote generated: true, location: :keep do
      alias Exop.Utils
      alias Exop.Validation
      alias Exop.ValidationChecks

      @type interrupt_result :: {:interrupt, any}
      @type auth_result :: :ok | no_return

      #  throws:
      #  {:error, {:auth, :undefined_policy}} |
      #  {:error, {:auth, :unknown_policy}}   |
      #  {:error, {:auth, :unknown_action}}   |
      #  {:error, {:auth, atom}}

      @exop_interruption :exop_interruption
      @exop_auth_error :exop_auth_error
      @no_value :exop_no_value

      if is_nil(@contract) || Enum.count(@contract) == 0 do
        file = String.to_charlist(__ENV__.file())
        line = __ENV__.line()
        stacktrace = [{__MODULE__, :process, 1, [file: file, line: line]}]
        msg = "An operation without a parameter definition"

        IO.warn(msg, stacktrace)
      end

      @spec contract :: list(map())
      def contract do
        @contract
      end

      @doc """
      Runs an operation's process/1 function after a contract validation
      """
      @spec run(Keyword.t() | map() | struct() | nil) ::
              {:ok, any}
              | Validation.validation_error()
              | interrupt_result
              | auth_result
              | {:error, any}
      def run(received_params \\ %{})

      def run(received_params) when is_list(received_params) do
        received_params |> Enum.into(%{}) |> run()
      end

      def run(%_{} = received_params) do
        received_params |> Map.from_struct() |> run()
      end

      def run(%{} = received_params) do
        params = Utils.defined_params(@contract, received_params)
        params = Utils.resolve_from(received_params, @contract, params)
        params = Utils.resolve_defaults(received_params, @contract, params)

        result = params |> Utils.resolve_coercions(@contract, params) |> output()

        with {:ok, _} = result <- result do
          result
        else
          error -> invoke_fallback(@fallback_module, params, error)
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
            raise(Validation.ValidationError, validation_error_message(reasons))

          {:error, _} = error ->
            raise(ErrorResult, error_result_message(error))

          result ->
            result
        end
      end

      @spec output(map()) ::
              {:ok, any()} | {:error, any()} | Validation.validation_error() | interrupt_result
      defp output(params) do
        case Enum.find(params, fn
               {_, {:error, error_msg}} -> true
               _ -> false
             end) do
          {_, {:error, _} = error} -> error
          _ -> output(params, Validation.valid?(@contract, params))
        end
      end

      @spec output(map(), :ok | {:error, {:validation, map()}}) ::
              {:ok, any()} | Validation.validation_error() | interrupt_result
      defp output(params, :ok = _validation_result) do
        try do
          result = process(params)

          case result do
            error_tuple when is_tuple(error_tuple) and elem(error_tuple, 0) == :error -> error_tuple
            {:ok, result} -> {:ok, result}
            _ -> {:ok, result}
          end
        catch
          {@exop_interruption, reason} -> {:interrupt, reason}
          {@exop_auth_error, reason} -> {:error, {:auth, reason}}
        end
      end

      defp output(_params, {:error, {:validation, errors}} = validation_result)
           when is_map(errors) do
        errors |> validation_error_message() |> Logger.warning()
        validation_result
      end

      defp validation_error_message(errors) do
        "#{@module_name} errors: \n#{Validation.errors_message(errors)}"
      end

      defp error_result_message(error), do: "#{@module_name} returned: \n#{inspect(error)}"

      @spec interrupt(any) :: no_return()
      def interrupt(reason \\ nil) do
        throw({@exop_interruption, reason})
      end

      @spec do_authorize(module(), atom(), any()) :: :ok | no_return()
      defp do_authorize(nil, _action, _opts) do
        throw({@exop_auth_error, :undefined_policy})
      end

      defp do_authorize(_policy, nil, _opts) do
        throw({@exop_auth_error, :undefined_action})
      end

      defp do_authorize(policy, action, opts) do
        try do
          if is_integer(policy.__info__(:functions)[action]) do
            case apply(policy, action, [opts]) do
              true -> :ok
              false -> throw({@exop_auth_error, action})
              reason -> throw({@exop_auth_error, reason})
            end
          else
            throw({@exop_auth_error, :unknown_policy})
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

  A parameter name could be either an atom or a string. You could even mix atom-named and
  string-named parameters in an operation's contract.

  ## Example
      parameter :some_param, type: :map, required: true
      parameter "my parameter", type: :map, required: true

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

  #### equals
  Checks whether a parameter's value exactly equals given value (with type equality).
      parameter :some_param, equals: 100.5

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

      def your_validation({param_name, param_value}, all_received_params_map) do
        # your validation logic based on given arguments is here
      end

  #### allow_nil
  It is not a parameter check itself, because it doesn't return any validation errors.
  It is a parameter attribute which allow you to have other checks for a parameter whilst have
  a possibility to pass `nil` as the parameter's value.
  If `nil` is passed all the parameter's checks are ignored during validation.

  #### from
  This option allows you to pass a parameter to `run/1` and `run!/1` functions with one name and
  work with this parameter within an operation under another name.

      parameter :a, type: :integer, from: "a"

  #### subset_of
  Checks whether a parameter's value (list) is a subset of a defined check-list.
  To pass this check, all items within given into an operation parameter should be included
  into check-list, otherwise the check is failed.

      parameter :some_param, subset_of: [1, 2, :a, "b", C]

  ## Interrupt
  In some cases you might want to make an 'early return' from `process/1` function.
  For this purpose you can call `interrupt/1` function within `process/1` and pass an interruption reason to it.
  An operation will be interrupted and return `{:interrupt, your_reason}`

      def process(_params) do
        interrupt(%{fail: "oops"})
        :ok # will not return it
      end

  ## Coercion

  It is possible to coerce a parameter before the contract validation, all validation checks
  will be invoked on coerced parameter value.
  Since coercion changes a parameter before any validation has been invoked,
  default values are resolved (with `:default` option) before the coercion.
  The flow looks like: `Resolve param default value -> Coerce -> Validate coerced`

      parameter :a, type: :string, coerce_with: &__MODULE__.to_string/2

      def to_string({:a, value}, %{} = _received_params) when is_integer(value) do
        Integer.to_string(value)
      end
      def to_string({:a, value}, %{} = _received_params) when is_binary(value) do
        value
      end

  _For more information and examples check out general Exop docs._
  """
  @spec parameter(atom() | binary(), keyword()) :: any()
  defmacro parameter(name, opts \\ []) when is_atom(name) or is_binary(name) do
    quote generated: true, bind_quoted: [name: name, opts: opts] do
      type_check = opts[:type]

      if is_map(opts) do
        @contract %{name: name, opts: [inner: opts]}
      else
        case TypeValidation.type_supported?(type_check, opts) do
          :ok ->
            @contract %{name: name, opts: opts}

          {:error, {:unknown_type, unknown_type}} ->
            raise ArgumentError,
                  "Unknown type check `#{inspect(unknown_type)}` for parameter `#{inspect(name)}` in module `#{
                    __MODULE__ |> Module.split() |> Enum.join(".")
                  }`, " <>
                    "supported type checks are `:#{Enum.join(TypeValidation.known_types(), "`, `:")}`."
        end
      end
    end
  end

  @doc """
  Defines a policy that will be used for authorizing the possibility of a user
  to invoke an operation.
      defmodule ReadOperation do
        use Exop.Operation

        policy MonthlyReportPolicy, :can_read?

        parameter :user, required: true, struct: User

        def process(params) do
          authorize(params.user)

          # make some reading...
        end
      end

  A policy itself might be:
      defmodule MonthlyReportPolicy do
        # not only Keyword or Map as an argument since 1.1.1
        def can_read?(%User{role: "manager"}), do: true
        def can_read?(_opts), do: false

        def can_write?(%User{role: "manager"}), do: true
        def can_write?(_opts), do: false
      end
  """
  @spec policy(module(), atom()) :: any()
  defmacro policy(policy_module, action_name) when is_atom(action_name) do
    quote generated: true, bind_quoted: [policy_module: policy_module, action_name: action_name] do
      @policy_module policy_module
      @policy_action_name action_name
    end
  end

  @doc """
  Authorizes an action with predefined policy (see `Policy check` macro docs).
  If authorization fails, any code after (below) auth check will be postponed (an error `{:error, {:auth, _reason}}` will be returned immediately)
  """
  @spec authorize(any()) :: any()
  defmacro authorize(opts \\ nil) do
    quote generated: true, bind_quoted: [opts: opts] do
      do_authorize(@policy_module, @policy_action_name, opts)
    end
  end

  @doc """
  Returns policy that was defined in an operation.
  """
  @spec current_policy() :: any()
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
  @spec fallback(module(), any()) :: any()
  defmacro fallback(fallback_module, opts \\ []) do
    quote generated: true, bind_quoted: [fallback_module: fallback_module, opts: opts] do
      with {:module, _} <- Code.ensure_compiled(fallback_module),
           true <- function_exported?(fallback_module, :process, 3) do
        @fallback_module %{module: fallback_module, opts: opts}
      else
        _ ->
          IO.warn("#{@module_name}: #{fallback_module}.run/1 wasn't found")
          @fallback_module nil
      end
    end
  end
end
