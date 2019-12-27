defmodule FallbackTest do
  use ExUnit.Case, async: false

  defmodule TestFallback do
    use Exop.Fallback

    def process(operation, params, error), do: {operation, params, error}
  end

  defmodule TestOperation do
    use Exop.Operation

    parameter :a, type: :integer
    parameter :b, type: :integer

    def process(%{a: a, b: b}), do: a + b
  end

  defmodule TestOperation1 do
    use Exop.Operation

    fallback TestFallback

    parameter :a, type: :integer
    parameter :b, type: :integer

    def process(%{a: a, b: b}), do: a + b
  end

  defmodule TestOperation2 do
    use Exop.Operation

    fallback TestFallback, return: true

    parameter :a, type: :integer
    parameter :b, type: :integer

    def process(%{a: a, b: b}), do: a + b
  end

  describe "fallback wasnt defined" do
    test "operation returns its error" do
      result = TestOperation.run(a: "a", b: 2)

      assert result ==
               {:error, {:validation, %{a: ["has wrong type; expected type: integer, got: \"a\""]}}}
    end
  end

  describe "fallback was defined" do
    test "operation returns its error if there is no return: true in a fallback opts" do
      result = TestOperation1.run(a: "a", b: 2)

      assert result ==
               {:error, {:validation, %{a: ["has wrong type; expected type: integer, got: \"a\""]}}}
    end

    test "operation returns a fallback result if there is return: true in a fallback opts" do
      result = TestOperation2.run(a: "a", b: 2)

      assert result == {
               FallbackTest.TestOperation2,
               %{a: "a", b: 2},
               {:error, {:validation, %{a: ["has wrong type; expected type: integer, got: \"a\""]}}}
             }
    end
  end
end
