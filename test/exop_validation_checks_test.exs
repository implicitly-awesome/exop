defmodule ExopValidationChecksTest do
  use ExUnit.Case, async: true

  doctest Exop.ValidationChecks

  import Exop.ValidationChecks

  test "get_check_item/2: returns value by key either from Keyword or Map" do
    assert get_check_item(%{a: 1, b: 2}, :a) == 1
    assert get_check_item([a: 1, b: 2], :b) == 2
  end

  test "get_check_item/2: returns nil if key was not found" do
    assert get_check_item(%{a: 1, b: 2}, :c) == nil
    assert get_check_item([a: 1, b: 2], :c) == nil
  end

  test "get_check_item/2: returns nil if first argument is not Keyword nor Map" do
    assert get_check_item({:a, 1, :b, 2}, :a) == nil
  end

  test "check_required/3: returns true if required = false" do
    assert check_required(%{}, :some_item, false) == true
  end

  test "check_required/3: returns true if item is in params and required = true" do
    assert check_required([a: 1, b: 2], :a, true) == true
  end

  test "check_required/3: returns %{item_name => error_msg} if item is not in params and required = true" do
    %{c: reason} = check_required([a: 1, b: 2], :c, true)
    assert is_binary(reason)
  end

  test "check_type/3: returns true if item is not in params" do
    assert check_type(%{}, :a, :integer) == true
  end

  test "check_type/3: returns true if item is of unhandled type" do
    assert check_type(%{a: 1}, :a, :unhandled) == true
  end

  test "check_type/3: returns true if item is one of handled type" do
    assert check_type(%{a: 1}, :a, :integer) == true
  end

  test "check_type/3: returns %{item_name => error_msg} if item is not of needed type" do
    %{a: reason} = check_type(%{a: "1"}, :a, :integer)
    assert is_binary(reason)
  end

  test "check_numericality/3: returns %{item_name => error_msg} if item is in params and is not a number" do
    %{a: reason} = check_numericality(%{a: "1"}, :a, %{ less_than: 3 })
    assert is_binary(reason)
  end

  test "check_numericality/3: returns true if item is not in params" do
    assert check_numericality(%{a: 1}, :b, %{ less_than: 3 }) == true
  end

  test "check_numericality/3: fails" do
    [%{a: _}] = check_numericality(%{a: 1}, :a, %{ equal_to: 3 })
    [%{a: _}] = check_numericality(%{a: 1}, :a, %{ greater_than: 3 })
    [%{a: _}] = check_numericality(%{a: 1}, :a, %{ greater_than_or_equal_to: 3 })
    [%{a: _}] = check_numericality(%{a: 5}, :a, %{ less_than: 3 })
    [%{a: _}] = check_numericality(%{a: 5}, :a, %{ less_than_or_equal_to: 3 })
  end

  test "check_numericality/3: successes" do
    assert check_numericality(%{a: 3}, :a, %{ equal_to: 3 }) == true
    assert check_numericality(%{a: 5}, :a, %{ greater_than: 3 }) == true
    assert check_numericality(%{a: 3}, :a, %{ greater_than_or_equal_to: 3 }) == true
    assert check_numericality(%{a: 5}, :a, %{ greater_than_or_equal_to: 3 }) == true
    assert check_numericality(%{a: 2}, :a, %{ less_than: 3 }) == true
    assert check_numericality(%{a: 3}, :a, %{ less_than_or_equal_to: 3 }) == true
    assert check_numericality(%{a: 2}, :a, %{ less_than_or_equal_to: 3 }) == true
  end

  test "check_in/3: returns true if check values is not a list" do
    assert check_in(%{a: 1}, :a, 2) == true
  end

  test "check_in/3: returns true if item is in check values list" do
    assert check_in(%{a: 1}, :a, [1, 2, 3]) == true
  end

  test "check_in/3: returns %{item_name => error_msg} if item is not in check values list" do
    %{a: _} = check_in(%{a: 4}, :a, [1, 2, 3])
  end

  test "check_not_in/3: returns true if check values is not a list" do
    assert check_not_in(%{a: 1}, :a, 2) == true
  end

  test "check_not_in/3: returns true if item is not in check values list" do
    assert check_not_in(%{a: 4}, :a, [1, 2, 3]) == true
  end

  test "check_not_in/3: returns %{item_name => error_msg} if item is in check values list" do
    %{a: _} = check_not_in(%{a: 3}, :a, [1, 2, 3])
  end

  test "check_format/3: returns true unless item is not a string" do
    assert check_format(%{a: 1}, :a, ~r/a/) == true
  end

  test "check_format/3: returns true if item is in valid format" do
    assert check_format(%{a: "bar"}, :a, ~r/bar/) == true
  end

  test "check_format/3: returns %{item_name => error_msg} unless item is in valid format" do
    %{a: _} = check_format(%{a: "foo"}, :a, ~r/bar/)
  end

  test "check_length/3: treat nil item's length as 0" do
    assert check_length(%{}, :a, %{min: 0}) == [true]
  end

  test "check_length/3: successes" do
    assert check_length(%{a: "123"}, :a, %{min: 0}) == [true]
    assert check_length(%{a: "123"}, :a, %{max: 4}) == [true]
    assert check_length(%{a: "123"}, :a, %{is: 3}) == [true]
    assert check_length(%{a: "123"}, :a, %{in: 2..4}) == [true]

    assert check_length(%{a: 3}, :a, %{min: 0}) == [true]
    assert check_length(%{a: 3}, :a, %{max: 4}) == [true]
    assert check_length(%{a: 3}, :a, %{is: 3}) == [true]
    assert check_length(%{a: 3}, :a, %{in: 2..4}) == [true]

    assert check_length(%{a: ~w(1 2 3)}, :a, %{min: 0}) == [true]
    assert check_length(%{a: ~w(1 2 3)}, :a, %{max: 4}) == [true]
    assert check_length(%{a: ~w(1 2 3)}, :a, %{is: 3}) == [true]
    assert check_length(%{a: ~w(1 2 3)}, :a, %{in: 2..4}) == [true]
  end

  test "check_length/3: fails" do
    [%{a: _}] = check_length(%{a: "123"}, :a, %{min: 4})
    [%{a: _}] = check_length(%{a: "123"}, :a, %{max: 2})
    [%{a: _}] = check_length(%{a: "123"}, :a, %{is: 4})
    [%{a: _}] = check_length(%{a: "123"}, :a, %{in: 4..6})

    [%{a: _}] = check_length(%{a: 3}, :a, %{min: 4})
    [%{a: _}] = check_length(%{a: 3}, :a, %{max: 2})
    [%{a: _}] = check_length(%{a: 3}, :a, %{is: 4})
    [%{a: _}] = check_length(%{a: 3}, :a, %{in: 4..6})

    [%{a: _}] = check_length(%{a: ~w(1 2 3)}, :a, %{min: 4})
    [%{a: _}] = check_length(%{a: ~w(1 2 3)}, :a, %{max: 2})
    [%{a: _}] = check_length(%{a: ~w(1 2 3)}, :a, %{is: 4})
    [%{a: _}] = check_length(%{a: ~w(1 2 3)}, :a, %{in: 4..6})
  end

  defmodule TestStruct do
    defstruct [:qwerty]
  end

  defmodule TestStruct2 do
    defstruct [:qwerty]
  end

  test "check_struct/3: successes" do
    assert check_struct(%{a: %TestStruct{qwerty: "123"}}, :a, %TestStruct{}) == true
  end

  test "check_struct/3: fails" do
    assert check_struct(%{a: %TestStruct2{}}, :a, %TestStruct{}) == %{a: "is not expected struct"}
    assert check_struct(%{a: %TestStruct2{qwerty: "123"}}, :a, %TestStruct{}) == %{a: "is not expected struct"}
    assert check_struct(%{a: %TestStruct2{}}, :a, %TestStruct{qwerty: "123"}) == %{a: "is not expected struct"}
    assert check_struct(%{a: %TestStruct2{qwerty: "123"}}, :a, %TestStruct{qwerty: "123"}) == %{a: "is not expected struct"}
  end
end
