defmodule Exop.Validation do
  @moduledoc """
    Provides high-level functions for a contract validation.
    The main function is valid?/2
    Mostly invokes Exop.ValidationChecks module functions.
  """

  require Logger

  alias Exop.ValidationChecks

  @type validation_error :: {:error, :validation_failed, Map.t}

  @spec function_present?(Module.t, String.t) :: boolean
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
  @spec valid?(list(Map.t), Keyword.t | Map.t) :: :ok | validation_error
  def valid?(contract, received_params) do
    validation_results = validate(contract, received_params, [])

    if Enum.all?(validation_results, &(&1 == true)) do
      :ok
    else
      error_results = validation_results |> consolidate_errors
      log_errors(error_results)
      {:error, :validation_failed, error_results}
    end
  end

  @spec consolidate_errors(list) :: Map.t
  defp consolidate_errors(validation_results) do
    error_results = validation_results |> Enum.reject(&(&1 == true))
    Enum.reduce(error_results, %{}, fn (error_result, map) ->
      item_name = Map.keys(error_result) |> List.first
      error_message = Map.get(error_result, item_name)

      Map.put(map, item_name, [error_message | (map[item_name] || [])])
    end)
  end

  @spec log_errors(Map.t) :: :ok | {:error, any}
  defp log_errors(errors) do
    unless Mix.env == :test, do: Logger.warn("#{__MODULE__} errors: \n#{errors_message(errors)}")
  end

  @spec errors_message(Map.t) :: String.t
  defp errors_message(errors) do
    result = for {item_name, error_messages} <- errors, into: [] do
      "#{item_name}: #{Enum.join(error_messages, "\n\t")}"
    end
    Enum.join(result, "\n")
  end

  @doc """
  Validate received params over a contract. Accumulate validation results into a list.

  ## Examples

    iex> Exop.Validation.validate([%{name: :param, opts: [required: true, type: :string]}], [param: "hello"], [])
    [true, true]
  """
  @spec validate([Map.t], Map.t | Keyword.t, list) :: list
  def validate([], _received_params, result), do: result
  def validate([contract_item | contract_tail], received_params, result) do
    checks_result = for {check_name, check_params} <- Map.get(contract_item, :opts), into: [] do
      check_function_name = ("check_" <> Atom.to_string(check_name)) |> String.to_atom
      cond do
        function_present?(__MODULE__, check_function_name) ->
          apply(__MODULE__, check_function_name, [received_params,
                                                  Map.get(contract_item, :name),
                                                  check_params])
        function_present?(ValidationChecks, check_function_name) ->
          apply(ValidationChecks, check_function_name, [received_params,
                                                       Map.get(contract_item, :name),
                                                       check_params])
        true ->
          true
      end
    end

    validate(contract_tail, received_params, result ++ List.flatten(checks_result))
  end

  @doc """
  Checks inner item of the contract param (which is a Map itself) with their own checks.

  ## Examples

    iex> Exop.Validation.check_inner(%{param: 1}, :param, [type: :integer, required: true])
    true
  """
  @spec check_inner(Map.t | Keyword.t, atom, Map.t | Keyword.t) :: list
  def check_inner(check_items, item_name, cheks) when is_map(cheks) do
     checked_param = ValidationChecks.get_check_item(check_items, item_name)

     inner_contract = for {inner_param_name, inner_param_checks} <- cheks, into: [] do
       %{ name: inner_param_name, opts:  inner_param_checks }
     end

     validate(inner_contract, checked_param, [])
  end

  def check_inner(_received_params, _contract_item_name, _check_params), do: true
end
