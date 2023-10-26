defmodule CallbackTest do
  use ExUnit.Case, async: false

  defmodule TestCallback do
    use Exop.Callback

    def process(operation, params, result, opts), do: send(self(), {operation, params, result, opts})
  end

  defmodule TestOperation do
    use Exop.Operation

    parameter :a, type: :integer
    parameter :b, type: :integer

    def process(%{a: a, b: b}), do: a + b
  end

  defmodule TestOperation1 do
    use Exop.Operation

    callback TestCallback

    parameter :a, type: :integer
    parameter :b, type: :integer

    def process(%{a: a, b: b}), do: a + b
  end

  describe "callback wasnt defined" do
    test "operation returns without callback" do
      result = TestOperation.run(a: 1, b: 2)

      assert result == {:ok, 3}
      refute_receive({
        CallbackTest.TestOperation,
        %{a: 1, b: 2},
        {:ok, 3},
        []
      })
    end
  end

  describe "callback was defined" do
    test "operation returns its result if there is no return: true in a callback opts" do
      result = TestOperation1.run(a: 1, b: 2)

      assert result == {:ok, 3}
      assert_receive({
        CallbackTest.TestOperation1,
        %{a: 1, b: 2},
        {:ok, 3},
        []
      })
    end
  end
end
