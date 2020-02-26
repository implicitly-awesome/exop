defmodule ChainTest do
  use ExUnit.Case, async: false

  defmodule Sum do
    use Exop.Operation

    parameter :a, type: :integer
    parameter :b, type: :integer

    def process(%{a: a, b: b}) do
      result = a + b
      _next_params = [a: result]
    end
  end

  defmodule MultiplyByHundred do
    use Exop.Operation

    parameter :a, type: :integer
    parameter :additional, type: :integer, required: false

    def process(%{a: a, additional: additional}) do
      result = a * 100 * additional
      _next_params = [a: result]
    end

    def process(%{a: a}) do
      result = a * 100
      _next_params = [a: result]
    end
  end

  defmodule DivisionByTen do
    use Exop.Operation

    parameter :a, type: :integer

    def process(params) do
      _chain_result = params[:a] / 10
    end
  end

  defmodule Fail do
    use Exop.Operation

    parameter :a, type: :string

    def process(_params), do: 1000
  end

  defmodule TestFallback do
    use Exop.Fallback

    def process(_operation, _params, _error), do: "fallback!"
  end

  defmodule WithFallback do
    use Exop.Operation

    fallback TestFallback, return: true

    parameter :a, type: :string

    def process(_params), do: 1000
  end

  defmodule TestChainSuccess do
    use Exop.Chain

    operation Sum
    operation MultiplyByHundred
    operation DivisionByTen
  end

  defmodule TestChainFail do
    use Exop.Chain

    operation Sum
    operation Fail
    operation DivisionByTen
  end

  defmodule TestChainFallback do
    use Exop.Chain

    operation Sum
    operation WithFallback
    operation DivisionByTen
  end

  test "invokes defined operations one by one and return the last result" do
    initial_params = [a: 1, b: 2]
    result = TestChainSuccess.run(initial_params)

    assert {:ok, 30.0} = result
  end

  test "invokes defined operations one by one and return the first not-ok-tuple-result" do
    initial_params = [a: 1, b: 2]
    result = TestChainFail.run(initial_params)

    assert {:error, {:validation, %{a: ["has wrong type; expected type: string, got: 3"]}}} = result
  end

  test "invokes a fallback module of a failed operation" do
    initial_params = [a: 1, b: 2]
    result = TestChainFallback.run(initial_params)

    assert result == "fallback!"
  end

  defmodule TestChainAdditionalParams do
    use Exop.Chain

    operation Sum
    operation MultiplyByHundred, additional: 2
    operation DivisionByTen
  end

  defmodule TestChainAdditionalParamsFunc do
    use Exop.Chain

    operation Sum
    operation MultiplyByHundred, additional: &__MODULE__.additional/0
    operation DivisionByTen

    def additional, do: 3
  end

  describe "with additional params" do
    test "allows to specify additional params" do
      initial_params = [a: 1, b: 2]
      result = TestChainAdditionalParams.run(initial_params)

      assert {:ok, 60.0} = result
    end

    test "allows to specify additional params as a 0-arity func" do
      initial_params = [a: 1, b: 2]
      result = TestChainAdditionalParamsFunc.run(initial_params)

      assert {:ok, 90.0} = result
    end
  end

  defmodule TestChainFailOpname do
    use Exop.Chain, name_in_error: true

    operation Sum
    operation Fail
    operation DivisionByTen
  end

  defmodule TestChainFallbackOpname do
    use Exop.Chain, name_in_error: true

    operation Sum
    operation WithFallback
    operation DivisionByTen
  end

  describe "with operation name in error output" do
    test "returns failed operation name" do
      initial_params = [a: 1, b: 2]
      result = TestChainFailOpname.run(initial_params)

      assert {ChainTest.Fail,
              {:error, {:validation, %{a: ["has wrong type; expected type: string, got: 3"]}}}} =
               result
    end

    test "doesn't affect an operation with a fallback" do
      initial_params = [a: 1, b: 2]
      result = TestChainFallbackOpname.run(initial_params)
      assert result == "fallback!"
    end
  end

  defmodule TestChainSuccessSteps do
    use Exop.Chain

    step Sum
    step MultiplyByHundred
    step DivisionByTen
  end

  test "step/2 is an alias for operation/2" do
    initial_params = [a: 1, b: 2]
    result = TestChainSuccessSteps.run(initial_params)

    assert {:ok, 30.0} = result
  end

  describe "with conditional steps" do
    defmodule TestChainConditionalSteps do
      use Exop.Chain

      operation Sum
      operation MultiplyByHundred, if: &__MODULE__.greater_than_10/1
      operation DivisionByTen

      def greater_than_10(%{a: a}) when a > 10, do: true
      def greater_than_10(_x), do: false
    end

    defmodule TestChainConditionalSteps2 do
      use Exop.Chain

      step Sum
      step MultiplyByHundred, if: &__MODULE__.greater_than_10/1
      step DivisionByTen, if: &__MODULE__.greater_than_10_000/1

      def greater_than_10(%{a: a}) when a > 10, do: true
      def greater_than_10(_x), do: false

      def greater_than_10_000(%{a: a}) when a > 10_000, do: true
      def greater_than_10_000(_x), do: false
    end

    test "invokes a step with a condition" do
      assert {:ok, [a: 3]} = TestChainConditionalSteps.run(a: 1, b: 2)
      assert {:ok, 110.0} = TestChainConditionalSteps.run(a: 4, b: 7)

      assert {:ok, [a: 3]} = TestChainConditionalSteps2.run(a: 1, b: 2)
      assert {:ok, [a: 1100]} = TestChainConditionalSteps2.run(a: 4, b: 7)
      assert {:ok, 1100.0} = TestChainConditionalSteps2.run(a: 40, b: 70)
    end

    test "interrupts a chain on error result" do
      assert {:error, {:validation, %{a: ["has wrong type; expected type: integer, got: \"1\""]}}} =
               TestChainConditionalSteps.run(a: "1", b: 2)

      assert {:error, {:validation, %{b: ["has wrong type; expected type: integer, got: \"2\""]}}} =
               TestChainConditionalSteps2.run(a: 1, b: "2")
    end
  end

  describe "with previous operation's output coercion" do
    defmodule TestChainCoercedSteps do
      use Exop.Chain

      operation Sum
      operation MultiplyByHundred, coerce_with: &__MODULE__.coerce/1
      operation DivisionByTen

      def coerce(%{a: a} = params), do: %{params | a: a * 10}
    end

    test "changes an incoming params" do
      assert {:ok, 300.0} = TestChainCoercedSteps.run(a: 1, b: 2)
      assert {:ok, 3000.0} = TestChainCoercedSteps.run(a: 10, b: 20)
    end

    defmodule TestChainCoercedSteps2 do
      use Exop.Chain

      operation Sum

      operation MultiplyByHundred,
        if: &__MODULE__.greater_than_100/1,
        coerce_with: &__MODULE__.coerce/1

      operation DivisionByTen

      def coerce(%{a: a} = params), do: %{params | a: a * 2}

      def greater_than_100(%{a: a}) when a > 100, do: true
      def greater_than_100(_x), do: false
    end

    test "respects if condition" do
      assert {:ok, [a: 3]} = TestChainCoercedSteps2.run(a: 1, b: 2)
      assert {:ok, [a: 30]} = TestChainCoercedSteps2.run(a: 10, b: 20)
      assert {:ok, 6000.0} = TestChainCoercedSteps2.run(a: 100, b: 200)
    end

    defmodule TestChainCoercedSteps3 do
      use Exop.Chain

      operation Sum
      operation MultiplyByHundred, additional: 5, coerce_with: &__MODULE__.coerce/1
      operation DivisionByTen

      def coerce(%{a: a} = params), do: %{params | a: a * 2}
    end

    test "respects additional params" do
      assert {:ok, 300.0} = TestChainCoercedSteps3.run(a: 1, b: 2)
    end
  end
end
