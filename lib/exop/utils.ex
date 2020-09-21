defmodule Exop.Utils do
  @moduledoc """
  A bunch of common functions.
  """

  @no_value :exop_no_value

  alias Exop.ValidationChecks

  @doc "Tries to make a map from a struct and keyword list"
  @spec try_map(any()) :: map() | nil
  def try_map(%_{} = struct), do: Map.from_struct(struct)

  def try_map(%{} = map), do: map

  def try_map([x | _] = keyword) when is_tuple(x), do: Enum.into(keyword, %{})

  def try_map([] = list) when length(list) == 0, do: %{}

  def try_map(_), do: nil

  @spec put_param_value(any(), Keyword.t() | map(), atom() | String.t()) ::
          Keyword.t() | map()
  def put_param_value(@no_value, collection, _item_name), do: collection

  def put_param_value(value, collection, item_name) when is_map(collection) do
    Map.put(collection, item_name, value)
  end

  @spec defined_params(list(), map()) :: map()
  def defined_params(contract, received_params)
      when is_list(contract) and is_map(received_params) do
    Map.take(received_params, Enum.map(contract, & &1[:name]))
  end

  @spec resolve_from(map(), list(%{name: atom() | String.t(), opts: Keyword.t()}), map()) :: map()
  def resolve_from(_received_params, [], resolved_params), do: resolved_params

  def resolve_from(
        received_params,
        [%{name: contract_item_name, opts: contract_item_opts} | contract_tail],
        resolved_params
      ) do
    alias_name = Keyword.get(contract_item_opts, :from)

    resolved_params =
      if alias_name do
        received_params
        |> Map.get(alias_name, @no_value)
        |> put_param_value(resolved_params, contract_item_name)
        |> Map.delete(alias_name)
      else
        resolved_params
      end

    resolve_from(received_params, contract_tail, resolved_params)
  end

  @spec resolve_defaults(map(), list(%{name: atom() | String.t(), opts: Keyword.t()}), map()) ::
          map()
  def resolve_defaults(_received_params, [], resolved_params), do: resolved_params

  def resolve_defaults(
        received_params,
        [%{name: contract_item_name, opts: contract_item_opts} | contract_tail],
        resolved_params
      ) do
    resolved_params =
      if Keyword.has_key?(contract_item_opts, :default) &&
           !ValidationChecks.check_item_present?(received_params, contract_item_name) do
        default_value = Keyword.get(contract_item_opts, :default)

        default_value =
          if is_function(default_value) do
            default_value.(received_params)
          else
            default_value
          end

        put_param_value(default_value, resolved_params, contract_item_name)
      else
        resolved_params
      end

    resolve_defaults(received_params, contract_tail, resolved_params)
  end

  @spec resolve_coercions(map(), list(%{name: atom() | String.t(), opts: Keyword.t()}), map()) ::
          any()
  def resolve_coercions(_received_params, [], coerced_params), do: coerced_params

  def resolve_coercions(
        received_params,
        [%{name: contract_item_name, opts: contract_item_opts} | contract_tail],
        coerced_params
      ) do
    if ValidationChecks.check_item_present?(received_params, contract_item_name) do
      inner = fetch_inner_checks(contract_item_opts)

      coerced_params =
        if is_map(inner) do
          inner_params = Map.get(received_params, contract_item_name)

          coerced_inners =
            Enum.reduce(inner, %{}, fn {contract_item_name, contract_item_opts}, acc ->
              coerced_value =
                resolve_coercions(
                  inner_params,
                  [%{name: contract_item_name, opts: contract_item_opts}],
                  inner_params
                )

              if is_map(coerced_value) do
                to_put = Map.get(coerced_value, contract_item_name, @no_value)

                if to_put == @no_value, do: acc, else: Map.put_new(acc, contract_item_name, to_put)
              else
                coerced_value
              end
            end)

          if is_map(coerced_inners) do
            received_params[contract_item_name]
            |> Map.merge(coerced_inners)
            |> put_param_value(received_params, contract_item_name)
          else
            put_param_value(coerced_inners, received_params, contract_item_name)
          end
        else
          if Keyword.has_key?(contract_item_opts, :coerce_with) do
            coerce_func = Keyword.get(contract_item_opts, :coerce_with)
            check_item = ValidationChecks.get_check_item(coerced_params, contract_item_name)
            coerced_value = coerce_func.({contract_item_name, check_item}, received_params)

            put_param_value(coerced_value, coerced_params, contract_item_name)
          else
            coerced_params
          end
        end

      resolve_coercions(coerced_params, contract_tail, coerced_params)
    else
      resolve_coercions(coerced_params, contract_tail, coerced_params)
    end
  end

  @spec fetch_inner_checks(list()) :: map() | nil
  def fetch_inner_checks([%{} = inner]), do: inner

  def fetch_inner_checks(contract_item_opts) when is_list(contract_item_opts) do
    Keyword.get(contract_item_opts, :inner)
  end

  def fetch_inner_checks(_), do: nil
end
