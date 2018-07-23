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
      params = %{param1: "param1"}
      Operation.run(params)
      assert called Exop.Validation.valid?(Operation.contract, params)
    end
  end

  test "process/1 takes a single param which is Map type" do
    assert Operation.run(param1: 1, param2: "string") == {:ok, ["This is the process/1 params", %{param1: 1, param2: "string"}]}
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

  test "run/1: returns an the last defined value for duplicated keys" do
    defmodule Def6Operation do
      use Exop.Operation

      parameter :a
      parameter :b

      def process(params), do: params
    end

    assert Def6Operation.run(a: 1, b: 3) == {:ok, %{a: 1, b: 3}}
    assert Def6Operation.run(%{a: 1, b: 3}) == {:ok, %{a: 1, b: 3}}
    assert Def6Operation.run(a: 1, a: 3) == {:ok, %{a: 3}}
  end

  test "interrupt/1: interupts process and returns the interuption result" do
    defmodule Def7Operation do
      use Exop.Operation

      def process(_params) do
        interrupt(%{my_error: "oops"})
        :ok
      end
    end

    assert Def7Operation.run == {:interrupt, %{my_error: "oops"}}
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

    def test(_opts), do: true
  end

  defmodule FalsePolicy do
    use Exop.Policy

    def test(_opts), do: false
  end

  defmodule TestUser do
    defstruct [:name, :email]
  end

  test "stores policy module and action" do
    defmodule Def9Operation do
      use Exop.Operation

      policy TruePolicy, :test

      def process(_params), do: current_policy()
    end

    assert Def9Operation.run == {:ok, {TruePolicy, :test}}
  end

  test "authorizes with provided policy" do
    defmodule Def10Operation do
      use Exop.Operation

      policy TruePolicy, :test

      def process(_params), do: authorize(user: %TestUser{})
    end

    assert Def10Operation.run == {:ok, :ok}

    defmodule Def11Operation do
      use Exop.Operation

      policy FalsePolicy, :test

      def process(_params), do: authorize(user: %TestUser{})
    end

    assert Def11Operation.run == {:error, {:auth, :test}}
  end

  test "operation invokation stops if auth failed" do
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

      def process(_params), do: current_policy()
    end

    assert Def16Operation.run == {:ok, {FalsePolicy, :test}}
  end

  test "coerce option changes a parameter value (and after defaults resolving)" do
    defmodule Def17Operation do
      use Exop.Operation

      parameter :a, default: 5, coerce_with: &__MODULE__.coerce/1
      parameter :b

      def process(params), do: {params[:a], params[:b]}

      def coerce(x), do: x * 2
    end

    assert Def17Operation.run(b: 0) == {:ok, {10, 0}}
  end

  test "coerce option changes a parameter value before validation" do
    defmodule Def18Operation do
      use Exop.Operation

      parameter :a, numericality: %{greater_than: 0}, coerce_with: &__MODULE__.coerce/1

      def process(params), do: params[:a]

      def coerce(x), do: x * 2
    end

    defmodule Def19Operation do
      use Exop.Operation

      parameter :a, required: true, coerce_with: &__MODULE__.coerce/1

      def process(params), do: params[:a]

      def coerce(_x), do: nil
    end

    defmodule Def20Operation do
      use Exop.Operation

      parameter :a, func: &__MODULE__.validate/2, coerce_with: &__MODULE__.coerce/1

      def process(params), do: params[:a]

      def validate(_params, x), do: x > 0

      def coerce(_x), do: 0
    end

    assert Def18Operation.run(a: 2) == {:ok, 4}
    assert Def18Operation.run(a: 0) == {:error, {:validation, %{a: ["must be greater than 0"]}}}

    assert Def19Operation.run(a: "str") == {:error, {:validation, %{a: ["is required"]}}}

    assert Def20Operation.run(a: 100) == {:error, {:validation, %{a: ["isn't valid"]}}}
  end

  test "run!/1: return operation's result with valid params" do
    defmodule Def21Operation do
      use Exop.Operation

      parameter :param, required: true

      def process(params) do
        params[:param] <> " World!"
      end
    end

    assert Def21Operation.run!(param: "Hello") == "Hello World!"
  end

  test "run!/1: return an error with invalid params" do
    defmodule Def22Operation do
      use Exop.Operation

      parameter :param, required: true

      def process(params) do
        params[:param] <> " World!"
      end
    end

    assert_raise Exop.Validation.ValidationError, fn -> Def22Operation.run! end
  end

  test "run!/1: doesn't affect unhandled errors" do
    defmodule Def23Operation do
      use Exop.Operation

      parameter :param, required: true

      def process(_params), do: raise("oops")
    end

    assert_raise RuntimeError, "oops", fn -> Def23Operation.run!(param: "hi!") end
  end

  test "run!/1: doesn't affect interruptions" do
    defmodule Def24Operation do
      use Exop.Operation

      parameter :param

      def process(_params), do: interrupt()
    end

    assert Def24Operation.run! == {:interrupt, nil}
  end

  test "run/1: returns unwrapped error tuple if process/1 returns it" do
    defmodule Def25Operation do
      use Exop.Operation

      parameter :param

      def process(params) do
        if params[:param], do: params[:param], else: {:error, :ooops}
      end
    end

    assert Def25Operation.run(param: 111) == {:ok, 111}
    assert Def25Operation.run(param: nil) == {:error, :ooops}
  end

  test "run!/1: returns unwrapped error tuple if process/1 returns it" do
    defmodule Def26Operation do
      use Exop.Operation

      parameter :param

      def process(params) do
        if params[:param], do: params[:param], else: {:error, :ooops}
      end
    end

    assert Def26Operation.run!(param: 111) == 111
    assert Def26Operation.run!(param: nil) == {:error, :ooops}
  end

  test "custom validation function takes a contract as the first parameter" do
    defmodule Def27Operation do
      use Exop.Operation

      parameter :a, default: 5
      parameter :b, func: &__MODULE__.custom_validation/2

      def process(params), do: {params[:a], params[:b]}

      def custom_validation(params, b) do
        params[:a] > 10 && b < 10
      end
    end

    assert Def27Operation.run(a: 11, b: 0) == {:ok, {11, 0}}
    assert Def27Operation.run(a: 0, b: 0) == {:error, {:validation, %{b: ["isn't valid"]}}}
  end

  test "run/1: returns unwrapped tuple {:ok, result} if process/1 returns {:ok, result}" do
    defmodule Def28Operation do
      use Exop.Operation

      parameter :param, required: true

      def process(params) do
        {:ok, params[:param]}
      end
    end

    assert Def28Operation.run(param: "hello") == {:ok, "hello"}
  end

  test "list_item + default value" do
    defmodule Def29Operation do
      use Exop.Operation

      parameter :param, list_item: %{type: :string, length: %{min: 7}}, default: ["1234567", "7chars"]

      def process(params) do
        {:ok, params[:param]}
      end
    end

    assert Def29Operation.run() == {:error, {:validation, %{item_1: ["length must be greater than or equal to 7"]}}}
  end

  test "list_item + coerce_with" do
    defmodule Def30Operation do
      use Exop.Operation

      parameter :param, list_item: %{type: :string, length: %{min: 7}}, coerce_with: &__MODULE__.make_list/1

      def process(params) do
        {:ok, params[:param]}
      end

      def make_list(_), do: ["1234567", "7chars"]
    end

    assert Def30Operation.run() == {:error, {:validation, %{item_1: ["length must be greater than or equal to 7"]}}}
  end
end
