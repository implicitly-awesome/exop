defmodule Exop.Utils do
  @moduledoc """
  A bunch of common functions.
  """

  @doc "Tries to make a map from a struct and keyword list"
  @spec try_map(any()) :: map() | nil
  def try_map(%_{} = struct), do: Map.from_struct(struct)
  def try_map(%{} = map), do: map
  def try_map([x | _] = keyword) when is_tuple(x), do: Enum.into(keyword, %{})
  def try_map([] = list) when length(list) == 0, do: %{}
  def try_map(_), do: nil
end
