defmodule ExopStringCharsImplementationsTest do
  use ExUnit.Case, async: true

  test "implements String.Chars for Range" do
    assert "This is a Range: #{1..2}" == "This is a Range: 1..2"
  end
end
