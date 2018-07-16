defmodule Exop.StringCharsImplementations do
  @moduledoc """
  String.Chars protocol implementations for some types
  """
  defimpl String.Chars, for: Range do
    @spec to_string(Range.t()) :: String.t()
    def to_string(term) do
      first..last = term
      "#{first}..#{last}"
    end
  end
end
