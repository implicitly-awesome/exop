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

  @type interrupt_error :: {:error, {:interrupt, any}}
  @type auth_result :: :ok |
                       {:error, {:auth, :undefined_user}} |
                       {:error, {:auth, :undefined_policy}} |
                       {:error, {:auth, :undefined_action}} |
                       {:error, {:auth, atom}}


  @callback process(Keyword.t | map()) :: {:ok, any} |
                                          Validation.validation_error |
                                          interrupt_error

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :contract, accumulate: true)
      Module.register_attribute(__MODULE__, :policy_module, [])
      Module.register_attribute(__MODULE__, :policy_action_name, [])

      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      alias Exop.Validation

      @type interrupt_error :: {:error, {:interrupt, any}}
      @type auth_result :: :ok |
                           {:error, {:auth, :undefined_user}}   |
                           {:error, {:auth, :undefined_policy}} |
                           {:error, {:auth, :unknown_policy}}   |
                           {:error, {:auth, :unknown_action}}   |
                           {:error, {:auth, atom}}

      @exop_invalid_error :exop_invalid_error
      @exop_auth_error :exop_auth_error

      @spec contract :: list(map())
      def contract do
        @contract
      end

      @doc """
      Runs an operation's process/1 function after a contract's validation
      """
      @spec run(Keyword.t | map() | nil) :: {:ok, any} | Validation.validation_error | interrupt_error
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
      @spec output(Keyword.t | map(), map() | :ok) :: {:ok, any} | Validation.validation_error | {:error, {:interrupt, any}}
      defp output(params, validation_result = :ok) do
        try do
          {:ok, process(params)}
        catch
          {@exop_invalid_error, reason} -> {:error, {:interrupt, reason}}
          {@exop_auth_error, reason} -> {:error, {:auth, reason}}
        end
      end
      defp output(_params, validation_result), do: validation_result

      @spec defined_params(Keyword.t | map()) :: map()
      def defined_params(received_params) when is_list(received_params) do
        keys_to_filter = Keyword.keys(received_params) -- Enum.map(@contract, &(&1[:name]))
        Keyword.drop(received_params, keys_to_filter) |> Enum.into(%{})
      end
      def defined_params(received_params) when is_map(received_params) do
        keys_to_filter = Map.keys(received_params) -- Enum.map(@contract, &(&1[:name]))
        Map.drop(received_params, keys_to_filter)
      end

      @spec interrupt(any) :: no_return
      def interrupt(reason \\ nil), do: throw({@exop_invalid_error, reason})

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

  @spec parameter(atom, Keyword.t) :: no_return
  defmacro parameter(name, opts \\ []) when is_atom(name) do
    quote bind_quoted: [name: name, opts: opts] do
      @contract %{name: name, opts: opts}
    end
  end

  @spec policy(Exop.Policy.t, atom) :: no_return
  defmacro policy(policy_module, action_name) when is_atom(action_name) do
    quote bind_quoted: [policy_module: policy_module, action_name: action_name] do
      @policy_module policy_module
      @policy_action_name action_name
    end
  end

  @spec authorize(any, Keyword.t | nil) :: auth_result
  defmacro authorize(user, opts \\ []) do
    quote bind_quoted: [user: user, opts: opts] do
      do_authorize(@policy_module, @policy_action_name, user, opts)
    end
  end

  @spec current_policy :: {Exop.Policy.t, atom}
  defmacro current_policy do
    quote do
      {@policy_module, @policy_action_name}
    end
  end
end