defmodule Exop.Validation do
  @moduledoc """
    Provides high-level functions for a contract validation.
    The main function is valid?/2
    Mostly invokes Exop.ValidationChecks module functions.
  """

  alias Exop.ValidationChecks

  @no_check_item :exop_no_check_item

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

  def validate([contract_item | contract_tail], received_params, result) do
    checks_result =
      if not required_param?(contract_item) && empty_param?(received_params, contract_item) do
        []
      else
        validate_params(contract_item, received_params)
      end

    validate(contract_tail, received_params, result ++ List.flatten(checks_result))
  end

  defp required_param?(%{opts: opts}), do: opts[:required] == true || false

  defp empty_param?(params, %{name: param_name}) do
    ValidationChecks.get_check_item(params, param_name) == @no_check_item
  end

  # defp empty_param?(params, %{name: param_name}) when is_map(params) do
  #   is_nil(Map.get(params, param_name))
  # end

  # defp empty_param?(params, %{name: param_name}), do: is_nil(params[param_name])

  defp validate_params(%{name: name, opts: opts} = _contract_item, received_params) do
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

  @doc """
  Checks inner item of the contract param (which is a Map itself) with their own checks.

  ## Examples

      iex> Exop.Validation.check_inner(%{param: 1}, :param, [type: :integer, required: true])
      true
  """
  @spec check_inner(map() | Keyword.t(), atom() | String.t(), map() | Keyword.t()) :: list
  def check_inner(check_items, item_name, checks) when is_map(checks) do
    checked_param = ValidationChecks.get_check_item(check_items, item_name)

    inner_contract =
      for {inner_param_name, inner_param_checks} <- checks, into: [] do
        %{name: inner_param_name, opts: inner_param_checks}
      end

    validate(inner_contract, checked_param, [])
  end

  def check_inner(_received_params, _contract_item_name, _check_params), do: true

  @spec check_list_item(map() | Keyword.t(), atom() | String.t(), map() | Keyword.t()) :: list
  def check_list_item(check_items, item_name, checks) when is_map(checks) do
    list = ValidationChecks.get_check_item(check_items, item_name)

    if is_list(list) do
      received_params =
        list
        |> Enum.with_index()
        |> Enum.reduce(%{}, fn {item, index}, map ->
          Map.put(map, String.to_atom("item_#{index}"), item)
        end)

      checks =
        Enum.reduce(received_params, %{}, fn {param_name, _}, map ->
          Map.put(map, param_name, checks)
        end)

      inner_contract =
        for {inner_param_name, inner_param_checks} <- checks, into: [] do
          %{name: inner_param_name, opts: inner_param_checks}
        end

      Enum.map(inner_contract, fn contract_item ->
        validate_params(contract_item, received_params)
      end)
    else
      [%{String.to_atom("#{item_name}") => "is not a list"}]
    end
  end
end
