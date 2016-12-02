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
    assert Operation.run(param1: 1, param2: "string") == {:ok, ["This is the process/1 params", [param1: 1, param2: "string"]]}
  end

  test "run/1: returns :validation_failed error when contract didn't pass validation" do
    {:error, {:validation, reasons}} = Operation.run(param1: "not integer", param2: 777)
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

    assert DefOperation.run == {:ok, 999}
  end

  test "run/1: pass default value of required missed parameter (thus pass a validation)" do
    defmodule Def2Operation do
      use Exop.Operation

      parameter :param, required: true, default: 999

      def process(params) do
        params[:param]
      end
    end

    assert Def2Operation.run == {:ok, 999}
  end

  test "run/1: doesn't pass default value if a parameter was passed to run/1" do
    defmodule Def3Operation do
      use Exop.Operation

      parameter :param, type: :integer, default: 999

      def process(params) do
        params[:param]
      end
    end

    assert Def3Operation.run(param: 111) == {:ok, 111}
  end

  test "params/1: doesn't invoke a contract validation" do
    assert Operation.process(param1: "not integer", param2: 777) == ["This is the process/1 params", [param1: "not integer", param2: 777]]
  end

  test "defined_params/0: returns params that were defined in the contract, filter out others" do
    defmodule Def4Operation do
      use Exop.Operation

      parameter :a
      parameter :b

      def process(params) do
        params |> defined_params
      end
    end

    assert Def4Operation.run(a: 1, b: 2, c: 3) == {:ok, %{a: 1, b: 2}}
  end

  test "defined_params/0: respects defaults" do
    defmodule Def5Operation do
      use Exop.Operation

      parameter :a
      parameter :b, default: 2

      def process(params) do
        params |> defined_params
      end
    end

    assert Def5Operation.run(a: 1, c: 3) == {:ok, %{a: 1, b: 2}}
  end

  test "run/1: returns an error if received given params Keyword has duplicated keys" do
    defmodule Def6Operation do
      use Exop.Operation

      parameter :a
      parameter :b

      def process(_params), do: :ok
    end

    assert Def6Operation.run(a: 1, b: 3) == {:ok, :ok}
    assert Def6Operation.run(%{a: 1, b: 3}) == {:ok, :ok}
    assert Def6Operation.run(a: 1, a: 3) == {:error, {:validation, %{params: "There are duplicates in received params list"}}}
  end

  test "interrupt/1: interupts process and returns the interuption error" do
    defmodule Def7Operation do
      use Exop.Operation

      def process(_params) do
        interrupt(%{my_error: "oops"})
        :ok
      end
    end

    assert Def7Operation.run == {:error, {:interrupt, %{my_error: "oops"}}}
  end

  test "interrupt/1: pass other exceptions" do
    defmodule Def8Operation do
      use Exop.Operation

      def process(_params) do
        raise "runtime error"
        interrupt(%{my_error: "oops"})
        :ok
      end
    end

    assert_raise(RuntimeError, fn -> Def8Operation.run end)
  end

  defmodule TruePolicy do
    use Exop.Policy

    def test(_user, _opts), do: true
  end

  defmodule FalsePolicy do
    use Exop.Policy

    def test(_user, _opts), do: false
  end

  defmodule TestUser do
    defstruct [:name, :email] 
  end

  test "stores policy module and action" do
    defmodule Def9Operation do
      use Exop.Operation

      policy TruePolicy, :test

      def process(_params), do: current_policy
    end

    assert Def9Operation.run == {:ok, {TruePolicy, :test}}
  end

  test "authorizes with provided policy" do
    defmodule Def10Operation do
      use Exop.Operation

      policy TruePolicy, :test

      def process(_params), do: authorize(%TestUser{})
    end

    assert Def10Operation.run == {:ok, :ok}

    defmodule Def11Operation do
      use Exop.Operation

      policy FalsePolicy, :test

      def process(_params), do: authorize(%TestUser{})
    end

    assert Def11Operation.run == {:error, {:auth, :test}}
  end

  test "operation invokeation stops if auth failed" do
    defmodule Def12Operation do
      use Exop.Operation

      policy FalsePolicy, :test

      def process(_params) do
        authorize %TestUser{}
        :you_will_never_get_here
      end
    end

    assert Def12Operation.run == {:error, {:auth, :test}}
  end

  test "returns errors with malformed policy definition" do
    defmodule Def14Operation do
      use Exop.Operation
      policy UnknownPolicy, :test

      def process(_params), do: authorize(%TestUser{})
    end

    defmodule Def15Operation do
      use Exop.Operation
      policy TruePolicy, :unknown_action

      def process(_params), do: authorize(%TestUser{})
    end

    assert Def14Operation.run == {:error, {:auth, :unknown_policy}}
    assert Def15Operation.run == {:error, {:auth, :unknown_policy}}
  end

  test "the last policy definition overrides previous definitions" do
    defmodule Def16Operation do
      use Exop.Operation
      policy TruePolicy, :test
      policy FalsePolicy, :test

      def process(_params), do: current_policy      
    end

    assert Def16Operation.run == {:ok, {FalsePolicy, :test}}
  end
end
