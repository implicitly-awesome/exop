defmodule Exop.TypeValidation do
  @known_types ~w(boolean integer float string tuple struct map list atom function keyword module)a

  Enum.each(@known_types, fn type ->
    def type_supported?(unquote(type)), do: true
  end)

  def type_supported?(_unknown_type), do: false

  def known_types, do: @known_types

  def check_value(check_item, :boolean) when is_boolean(check_item), do: true

  def check_value(check_item, :integer) when is_integer(check_item), do: true

  def check_value(check_item, :float) when is_float(check_item), do: true

  def check_value(check_item, :string) when is_binary(check_item), do: true

  def check_value(check_item, :tuple) when is_tuple(check_item), do: true

  def check_value(%_{} = _check_item, :struct) do
    IO.warn("type check with :struct is deprecated, please use :map instead")
    true
  end

  def check_value(_check_item, :struct) do
    IO.warn("type check with :struct is deprecated, please use :map instead")
    false
  end

  def check_value(check_item, :map) when is_map(check_item), do: true

  def check_value(check_item, :list) when is_list(check_item), do: true

  def check_value(check_item, :atom) when is_atom(check_item), do: true

  def check_value(check_item, :function) when is_function(check_item), do: true

  def check_value([] = _check_item, :keyword), do: true

  def check_value([{atom, _} | _] = _check_item, :keyword) when is_atom(atom), do: true

  def check_value(check_item, :module) when is_atom(check_item) do
    Code.ensure_loaded?(check_item)
  end

  def check_value(_, _), do: false
end
