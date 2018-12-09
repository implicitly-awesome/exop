defmodule Exop.Validation do
  @moduledoc """
    Provides high-level functions for a contract validation.
    The main function is valid?/2
    Mostly invokes Exop.ValidationChecks module functions.
  """

  alias Exop.ValidationChecks

  defmodule ValidationError do
    @moduledoc """
      An operation's contract validation failure error.
    """
    defexception message: "Contract validation failed"
  end

  @type validation_error :: {:error, {:validation, map()}}

  @spec function_present?(Elixir.Exop.Validation | Elixir.Exop.ValidationChecks, atom()) ::
          boolean()
  defp function_present?(module, function_name) do
    :functions
    |> module.__info__
    |> Keyword.has_key?(function_name)
  end

  @doc """
  Validate received params over a contract.

  ## Examples

      iex> Exop.Validation.valid?([%{name: :param, opts: [required: true]}], [param: "hello"])
      :ok
  """
  @spec valid?(list(map()), Keyword.t() | map()) :: :ok | validation_error
  def valid?(contract, received_params) do
    validation_results = validate(contract, received_params, [])

    if Enum.empty?(validation_results) || Enum.all?(validation_results, &(&1 == true)) do
      :ok
    else
      error_results = validation_results |> consolidate_errors
      {:error, {:validation, error_results}}
    end
  end

  @spec consolidate_errors(list()) :: map()
  defp consolidate_errors(validation_results) do
    error_results = validation_results |> Enum.reject(&(&1 == true))

    Enum.reduce(error_results, %{}, fn error_result, map ->
      item_name = error_result |> Map.keys() |> List.first()
      error_message = Map.get(error_result, item_name)

      Map.put(map, item_name, [error_message | map[item_name] || []])
    end)
  end

  @spec errors_message(map()) :: String.t()
  def errors_message(errors) do
    errors
    |> Enum.map(fn {item_name, error_messages} ->
      "#{item_name}: #{Enum.join(error_messages, "\n\t")}"
    end)
    |> Enum.join("\n")
  end

  @doc """
  Validate received params over a contract. Accumulate validation results into a list.

  ## Examples

      iex> Exop.Validation.validate([%{name: :param, opts: [required: true, type: :string]}], [param: "hello"], [])
      [true, true]
  """
  @spec validate([map()], map() | Keyword.t(), list()) :: list()
  def validate([], _received_params, result), do: result

  def validate([%{name: name, opts: opts} = contract_item | contract_tail], received_params, result) do
    checks_result =
      if !required?(opts) && !present?(received_params, name) do
        []
      else
        validate_params(contract_item, received_params)
      end

    validate(contract_tail, received_params, result ++ List.flatten(checks_result))
  end

  defp present?(received_params, contract_item_name) do
    ValidationChecks.check_item_present?(received_params, contract_item_name)
  end

  defp required?(opts), do: opts[:required] != false

  defp explicit_required(opts) when is_list(opts) do
    if required?(opts), do: Keyword.put(opts, :required, true), else: opts
  end

  defp explicit_required(opts) when is_map(opts) do
    if required?(opts), do: Map.put(opts, :required, true), else: opts
  end

  defp validate_params(%{name: name, opts: opts} = _contract_item, received_params) do
    nil_is_allowed =
      opts[:allow_nil] == true && ValidationChecks.check_item_present?(received_params, name) &&
        is_nil(ValidationChecks.get_check_item(received_params, name))

    if nil_is_allowed do
      []
    else
      # see changelog for ver. 1.2.0: everything except `required: false` is `required: true`
      opts = explicit_required(opts)

      for {check_name, check_params} <- opts, into: [] do
        check_function_name = String.to_atom("check_#{check_name}")

        cond do
          function_present?(__MODULE__, check_function_name) ->
            apply(__MODULE__, check_function_name, [received_params, name, check_params])

          function_present?(ValidationChecks, check_function_name) ->
            apply(ValidationChecks, check_function_name, [received_params, name, check_params])

          true ->
            true
        end
      end
    end
  end

  @doc """
  Checks inner item of the contract param (which is a Map itself) with their own checks.

  ## Examples

      iex> Exop.Validation.check_inner(%{param: 1}, :param, [type: :integer, required: true])
      true
  """
  @spec check_inner(map() | Keyword.t(), atom() | String.t(), map() | Keyword.t()) :: list
  def check_inner(check_items, item_name, checks) when is_map(checks) do
    check_items
    |> ValidationChecks.get_check_item(item_name)
    |> case do
      %_{} = struct -> Map.from_struct(struct)
      %{} = map -> map
      [x | _] = keyword when is_list(keyword) and is_tuple(x) -> Enum.into(keyword, %{})
      [] -> %{}
      _ -> nil
    end
    |> do_check_inner(item_name, checks)
  end

  def check_inner(_received_params, _contract_item_name, _check_params), do: true

  defp do_check_inner(check_item, item_name, checks) when is_map(check_item) do
    received_params =
      Enum.reduce(check_item, %{}, fn {inner_param_name, _inner_param_value}, acc ->
        Map.put(acc, "#{item_name}[:#{inner_param_name}]", check_item[inner_param_name])
      end)

    for {inner_param_name, inner_opts} <- checks, into: [] do
      inner_name = "#{item_name}[:#{inner_param_name}]"
      validate_params(%{name: inner_name, opts: inner_opts}, received_params)
    end
  end

  defp do_check_inner(_check_item, item_name, _checks) do
    [%{item_name => "has wrong type"}]
  end

  @spec check_list_item(map() | Keyword.t(), atom() | String.t(), map() | Keyword.t()) :: list
  def check_list_item(check_items, item_name, checks) when is_list(checks) do
    check_list_item(check_items, item_name, Enum.into(checks, %{}))
  end

  def check_list_item(check_items, item_name, checks) when is_map(checks) do
    list = ValidationChecks.get_check_item(check_items, item_name)

    if is_list(list) do
      received_params =
        list
        |> Enum.with_index()
        |> Enum.reduce(%{}, fn {item, index}, acc ->
          Map.put(acc, "#{item_name}[#{index}]", item)
        end)

      for {param_name, _} <- received_params, into: [] do
        validate_params(%{name: param_name, opts: checks}, received_params)
      end
    else
      [%{String.to_atom("#{item_name}") => "is not a list"}]
    end
  end
end
