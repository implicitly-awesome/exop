defmodule ChainTest do
  use ExUnit.Case, async: false

  defmodule Sum do
    use Exop.Operation

    parameter :a, type: :integer
    parameter :b, type: :integer

    def process(params) do
      result = params[:a] + params[:b]
      _next_params = [a: result]
    end
  end

  defmodule MultiplyByHundred do
    use Exop.Operation

    parameter :a, type: :integer

    def process(params) do
      result = params[:a] * 100
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

    assert result == 30
  end

  test "invokes defined operations one by one and return the first not-ok-tuple-result" do
    initial_params = [a: 1, b: 2]
    result = TestChainFail.run(initial_params)

    assert result == {:error, {:validation, %{a: ["has wrong type"]}}}
  end

  test "invokes a fallback module of a failed operation" do
    initial_params = [a: 1, b: 2]
    result = TestChainFallback.run(initial_params)

    assert result == "fallback!"
  end
end
