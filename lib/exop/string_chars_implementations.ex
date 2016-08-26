defmodule Exop.StringCharsImplementations do
  defimpl String.Chars, for: Range do
    def to_string(term) do
      first..last = term
      "#{first}..#{last}"
    end
  end
end
