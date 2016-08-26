defmodule ExopOperationTest do
  use ExUnit.Case, async: false

  import Mock

  defmodule Operation do
    use Exop.Operation

    parameter :param1, type: :integer
    parameter :param2, type: :string

    def process(params) do
      ["This is the process", params]
    end
  end

  @valid_contract [
    %{name: :param1, opts: [type: :integer]},
    %{name: :param2, opts: [type: :string]}
  ]

  test "defines contract/0" do
    assert :functions |> Operation.__info__ |> Keyword.has_key?(:contract)
  end

  test "stores defined properties in a contract" do
    assert Operation.contract |> is_list
    assert Operation.contract |> List.first |> is_map
    assert Enum.sort(Operation.contract) == Enum.sort(@valid_contract)
  end

  test "defines run/1" do
    assert :functions |> Operation.__info__ |> Keyword.has_key?(:run)
  end

  test "run/1: calls Operation.Validation.valid?/2" do
    with_mock Exop.Validation, [valid?: fn(_, _) -> :ok end] do
      params = [param1: "param1"]
      Operation.run(params)
      assert called Exop.Validation.valid?(Operation.contract, params)
    end
  end

  test "run/1: calls process/1 on particular operation via delegate/3 when contract passed validation" do
    with_mock Exop.Validation, [valid?: fn(_, _) -> :ok end] do
      with_mock Exop.Operation.Delegator, [delegate: fn(_, _, _) -> true end] do
        params = [param1: "param1"]
        Operation.run(params)
        assert called Exop.Operation.Delegator.delegate(Operation, :process, params)
      end
    end
  end

  test "run/1: returns :validation_failed error when contract didnt pass validation" do
    with_mock Exop.Validation, [valid?: fn(_, _) -> {:error, :validation_failed, [some_error: "some_error"]} end] do
      assert Operation.run([]) == {:error, :validation_failed, [some_error: "some_error"]}
    end
  end
end
