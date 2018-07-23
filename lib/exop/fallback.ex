defmodule Exop.Fallback do
  @moduledoc """
  Provides macros for fallback handling.

  ## Example

      defmodule FallbackModule do
        use Exop.Fallback

        def process(operation, params, error) do
          # your error handling code here
          :some_fallback_result
        end
      end

      defmodule TestOperation do
        use Exop.Operation

        fallback FallbackModule, return: true

        parameter :a, type: :integer
        parameter :b, type: :integer

        def process(%{a: a, b: b}), do: a + b
      end

      # TestOperation.run(a: 1, b: "2") => :some_fallback_result

  By using `Exop.Fallback` you need to implement `process/3` function which takes following params:
    * failed operation module (`TestOperation` in the example above)
    * params that were passed into the operation (`%{a: 1, b: "2"}`)
    * an error result which was returned by the operation (`{:error, {:validation, %{a: ["has wrong type"]}}}`)

  During a fallback definition you can add `return: true` option so in the example case
  `TestOperation.run/1` will return the result of the fallback (`FallbackModule.process/3`
   function's result - `:some_fallback_result`).
  If you want `TestOperation.run/1` to return original result (`{:error, {:validation, %{a: ["has wrong type"]}}}`)
  specify `return: false` option or just omit it in a fallback definition.
  """

  @type t :: __MODULE__

  @doc """
  Fallback handling function.
  Receives:
    - failed operation module
    - a map of parameters with which the operation was invoked
    - an error tuple returned by the operation
  """
  @callback process(atom(), map(), any()) :: any()

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__)
    end
  end
end
