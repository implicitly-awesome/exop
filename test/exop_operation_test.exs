defmodule ExopOperationTest do
  use ExUnit.Case, async: false

  import Mock

  defmodule Operation do
    use Exop.Operation

    parameter :param1, type: :integer
    parameter :param2, type: :string

    def process(params) do
      ["This is the process/1 params", params]
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
    assert Operation.run(param1: 1, param2: "string") == ["This is the process/1 params", [param1: 1, param2: "string"]]
  end

  test "run/1: returns :validation_failed error when contract didn't pass validation" do
    {:error, :validation_failed, reasons} = Operation.run(param1: "not integer", param2: 777)
    assert is_map(reasons)
  end

  test "run/1: pass default value of missed parameter" do
    defmodule DefOperation do
      use Exop.Operation

      parameter :param2
      parameter :param, default: 999

      def process(params) do
        params[:param]
      end
    end

    assert DefOperation.run == 999
  end

  test "run/1: pass default value of required missed parameter (thus pass a validation)" do
    defmodule Def2Operation do
      use Exop.Operation

      parameter :param, required: true, default: 999

      def process(params) do
        params[:param]
      end
    end

    assert Def2Operation.run == 999
  end

  test "run/1: doesn't pass default value if a parameter was passed to run/1" do
    defmodule Def3Operation do
      use Exop.Operation

      parameter :param, type: :integer, default: 999

      def process(params) do
        params[:param]
      end
    end

    assert Def3Operation.run(param: 111) == 111
  end

  test "params/1: doesn't invoke a contract validation" do
    assert Operation.process(param1: "not integer", param2: 777) == ["This is the process/1 params", [param1: "not integer", param2: 777]]
  end
end
