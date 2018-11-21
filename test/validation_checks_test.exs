defmodule ValidationChecksTest do
  use ExUnit.Case, async: false

  doctest Exop.ValidationChecks

  import Exop.ValidationChecks

  test "get_check_item/2: returns value by key either from Keyword or Map" do
    assert get_check_item(%{a: 1, b: 2}, :a) == 1
    assert get_check_item([a: 1, b: 2], :b) == 2
  end

  test "get_check_item/2: returns nil if key was not found" do
    assert is_nil(get_check_item(%{a: 1, b: 2}, :c))
    assert is_nil(get_check_item([a: 1, b: 2], :c))
  end

  test "check_item_present?/2: checks whether a param has been provided" do
    assert check_item_present?(%{a: 1, b: 2}, :a) == true
    assert check_item_present?([a: 1, b: 2], :b) == true
    assert check_item_present?([a: 1, b: nil], :b) == true
    assert check_item_present?(%{a: 1, b: 2}, :c) == false
    assert check_item_present?([a: 1, b: 2], :c) == false
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

  test "check_required/3: returns true if item is in params and equal to false and required = true" do
    assert check_required([a: false, b: 2], :a, true)
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

  test "check_type/3: returns false if item is nil but type is not atom" do
    assert check_type(%{a: nil}, :a, :string) == %{:a => "has wrong type"}
  end

  test "check_type/3: checks module" do
    defmodule TestModule do
    end

    assert check_type(%{a: TestModule}, :a, :module) == true
    assert check_type(%{a: TestModule_2}, :a, :module) == %{a: "has wrong type"}
    assert check_type(%{a: :atom}, :a, :module) == %{a: "has wrong type"}
    assert check_type(%{a: 1}, :a, :module) == %{a: "has wrong type"}
  end

  test "check_numericality/3: returns %{item_name => error_msg} if item is in params and is not a number" do
    %{a: reason} = check_numericality(%{a: "1"}, :a, %{less_than: 3})
    assert is_binary(reason)
  end

  test "check_numericality/3: returns true if item is not in params" do
    assert check_numericality(%{a: 1}, :b, %{less_than: 3}) == true
  end

  test "check_numericality/3: fails" do
    [%{a: _}] = check_numericality(%{a: 1}, :a, %{equal_to: 3})
    [%{a: _}] = check_numericality(%{a: 1}, :a, %{greater_than: 3})
    [%{a: _}] = check_numericality(%{a: 1}, :a, %{greater_than_or_equal_to: 3})
    [%{a: _}] = check_numericality(%{a: 5}, :a, %{less_than: 3})
    [%{a: _}] = check_numericality(%{a: 5}, :a, %{less_than_or_equal_to: 3})
  end

  test "check_numericality/3: successes" do
    assert check_numericality(%{a: 3}, :a, %{equal_to: 3}) == true
    assert check_numericality(%{a: 5}, :a, %{greater_than: 3}) == true
    assert check_numericality(%{a: 3}, :a, %{greater_than_or_equal_to: 3}) == true
    assert check_numericality(%{a: 5}, :a, %{greater_than_or_equal_to: 3}) == true
    assert check_numericality(%{a: 2}, :a, %{less_than: 3}) == true
    assert check_numericality(%{a: 3}, :a, %{less_than_or_equal_to: 3}) == true
    assert check_numericality(%{a: 2}, :a, %{less_than_or_equal_to: 3}) == true
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

  test "check_regex/3: returns true unless item is not a string" do
    assert check_regex(%{a: 1}, :a, ~r/a/) == true
  end

  test "check_regex/3: returns true if item is in valid format" do
    assert check_regex(%{a: "bar"}, :a, ~r/bar/) == true
  end

  test "check_regex/3: returns %{item_name => error_msg} unless item is in valid format" do
    %{a: _} = check_regex(%{a: "foo"}, :a, ~r/bar/)
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
    struct = %TestStruct{qwerty: "123"}

    assert check_struct(%{a: struct}, :a, %TestStruct{}) == true
    assert check_struct(%{a: struct}, :a, TestStruct) == true
  end

  test "check_struct/3: fails" do
    assert check_struct(%{a: %TestStruct2{}}, :a, %TestStruct{}) == %{a: "is not expected struct"}
    assert check_struct(%{a: %TestStruct2{qwerty: "123"}}, :a, %TestStruct{}) == %{a: "is not expected struct"}
    assert check_struct(%{a: %TestStruct2{}}, :a, %TestStruct{qwerty: "123"}) == %{a: "is not expected struct"}
    assert check_struct(%{a: %TestStruct2{qwerty: "123"}}, :a, %TestStruct{qwerty: "123"}) == %{a: "is not expected struct"}
    assert check_struct(%{a: %TestStruct2{}}, :a, TestStruct) == %{a: "is not expected struct"}
    assert check_struct(%{a: %TestStruct2{qwerty: "123"}}, :a, TestStruct) == %{a: "is not expected struct"}
  end

  test "check_equals/3: success" do
    assert check_equals(%{a: 1.0}, :a, 1.0) == true
    assert check_equals(%{a: :a}, :a, :a) == true
    assert check_equals(%{a: [b: 2, c: 3]}, :a, [b: 2, c: 3]) == true
    assert check_equals(%{a: [b: 2, c: 3]}, :a, [{:b, 2}, {:c, 3}]) == true
    assert check_equals(%{a: %{b: 2, c: 3}}, :a, %{b: 2, c: 3}) == true
  end

  test "check_equals/3: fails" do
    assert check_equals(%{a: 1.0}, :a, 1) == %{a: "must be equal to 1"}
    assert check_equals(%{a: 1.0}, :a, 1.1) == %{a: "must be equal to 1.1"}
    assert check_equals(%{a: :a}, :a, :b) == %{a: "must be equal to :b"}
    assert check_equals(%{a: [b: 2, c: 3]}, :a, [b: 2, c: 1]) == %{a: "must be equal to [b: 2, c: 1]"}
    assert check_equals(%{a: [b: 2, c: 3]}, :a, [{:b, 2}]) == %{a: "must be equal to [b: 2]"}
    assert check_equals(%{a: %{b: 2, c: 3}}, :a, %{b: 2, d: 3}) == %{a: "must be equal to %{b: 2, d: 3}"}
  end

  test "check_exactly/3: success" do
    assert check_exactly(%{a: 1.0}, :a, 1.0) == true
    assert check_exactly(%{a: :a}, :a, :a) == true
    assert check_exactly(%{a: [b: 2, c: 3]}, :a, [b: 2, c: 3]) == true
    assert check_exactly(%{a: [b: 2, c: 3]}, :a, [{:b, 2}, {:c, 3}]) == true
    assert check_exactly(%{a: %{b: 2, c: 3}}, :a, %{b: 2, c: 3}) == true
  end

  test "check_exactly/3: fails" do
    assert check_exactly(%{a: 1.0}, :a, 1) == %{a: "must be equal to 1"}
    assert check_exactly(%{a: 1.0}, :a, 1.1) == %{a: "must be equal to 1.1"}
    assert check_exactly(%{a: :a}, :a, :b) == %{a: "must be equal to :b"}
    assert check_exactly(%{a: [b: 2, c: 3]}, :a, [b: 2, c: 1]) == %{a: "must be equal to [b: 2, c: 1]"}
    assert check_exactly(%{a: [b: 2, c: 3]}, :a, [{:b, 2}]) == %{a: "must be equal to [b: 2]"}
    assert check_exactly(%{a: %{b: 2, c: 3}}, :a, %{b: 2, d: 3}) == %{a: "must be equal to %{b: 2, d: 3}"}
  end

  def validation(params, :a, param_value), do: validation(params, param_value)
  def validation(_params, :b, _param_value), do: false

  def validation(_params, param_value) do
    param_value > 99
  end

  def validation_verbose(params, :a, param_value), do: validation_verbose(params, param_value)
  def validation_verbose(_params, :b, _param_value), do: false

  def validation_verbose(_params, param_value) do
    if param_value > 99 do
      true
    else
      {:error, "Custom error message"}
    end
  end

  test "check_func/3: success" do
    assert check_func(%{a: 100}, :a, &__MODULE__.validation/2) == true
    assert check_func(%{a: 100}, :a, &__MODULE__.validation_verbose/2) == true
  end

  test "check_func/3: fails" do
    assert check_func(%{a: 98}, :a, &__MODULE__.validation/2) == %{a: "isn't valid"}
    assert check_func(%{a: 98}, :a, &__MODULE__.validation_verbose/2) == %{a: "Custom error message"}
  end

  test "check_func/3: validation func can expect 3 args: params, param_name and param_value " do
    assert check_func(%{a: 100}, :a, &__MODULE__.validation/3) == true
    assert check_func(%{a: 100}, :a, &__MODULE__.validation_verbose/3) == true
    assert check_func(%{b: 100}, :b, &__MODULE__.validation_verbose/3) == %{b: "isn't valid"}

    assert check_func(%{a: 98}, :a, &__MODULE__.validation/3) == %{a: "isn't valid"}
    assert check_func(%{a: 98}, :a, &__MODULE__.validation_verbose/3) == %{a: "Custom error message"}
    assert check_func(%{b: 98}, :b, &__MODULE__.validation_verbose/3) == %{b: "isn't valid"}
  end

  test "check_numericality/3: aliases" do
    assert check_numericality(%{a: 3}, :a, %{equals: 3}) == true
    assert check_numericality(%{a: 2}, :a, %{equals: 3}) == [%{a: "must be equal to 3"}]
    assert check_numericality(%{a: 3}, :a, %{is: 3}) == true
    assert check_numericality(%{a: 2}, :a, %{is: 3}) == [%{a: "must be equal to 3"}]
    assert check_numericality(%{a: 3}, :a, %{min: 1}) == true
    assert check_numericality(%{a: 1}, :a, %{min: 3}) == [%{a: "must be greater than or equal to 3"}]
    assert check_numericality(%{a: 1}, :a, %{max: 3}) == true
    assert check_numericality(%{a: 3}, :a, %{max: 1}) == [%{a: "must be less than or equal to 1"}]
  end
end
