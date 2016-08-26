defmodule ExopValidationTest do
  use ExUnit.Case, async: false

  doctest Exop.Validation

  import Mock
  import Exop.Validation

  setup do
    contract = [
      %{
        name: :param,
        opts: [ required: true, type: :string ]
      },
      %{
        name: :param2,
        opts: [ type: :integer, in: [1, 2, 3] ]
      }
    ]

    %{contract: contract}
  end

  test "validate/3: returns true if item's contract has unknown check", _context do
    contract = [%{
      name: :param,
      opts: [ unknown_check: "whatever" ]
    }]
    assert validate(contract, %{param: "some_value"}, []) == [true]
  end

  test "validate/3: invokes related checks for a param's contract options", %{contract: contract} do
    with_mock Exop.ValidationChecks, [__info__: fn(_) -> [check_required: true, check_type: true] end,
                                                    check_required: fn(_, _, _) -> true end,
                                                    check_type: fn(_, _, _) -> true end] do

      validate(contract, %{param: "some_value"}, [])
      assert called Exop.ValidationChecks.check_required(%{param: "some_value"}, :param, true)
      assert called Exop.ValidationChecks.check_type(%{param: "some_value"}, :param, :string)
    end
  end

  test "validate/3: accumulates related checks results", %{contract: contract} do
    with_mock Exop.ValidationChecks, [__info__: fn(_) -> [check_required: true, check_type: true] end,
                                                    check_required: fn(_, _, _) -> true end,
                                                    check_type: fn(_, _, _) -> {:error, "wrong type"} end] do
      assert validate(contract, %{param: "some_value"}, []) == [true, {:error, "wrong type"}, {:error, "wrong type"}, true]
    end
  end

  test "valid?/2: returns :ok if all params conform the contract", %{contract: contract} do
    received_params = [param: "param", param2: 2]

    assert valid?(contract, received_params) == :ok
  end

  test "valid?/2: returns {:error, :validation_failed, reasons} if at least one
        of params doesn't conform the contract", %{contract: contract} do
    received_params = [param: "param", param2: 4]

    {:error, :validation_failed, reasons} = valid?(contract, received_params)
    assert is_list(reasons)
  end
end
