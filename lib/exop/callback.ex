defmodule Exop.Callback do
  @moduledoc """
  Provides macros for callback handling.

  ## Example

      defmodule CallbackModule do
        use Exop.Callback

        def process(operation, params, result, opts) do
          # your callback handling code here
        end
      end

      defmodule TestOperation do
        use Exop.Operation

        callback CallbackModule, return: true

        parameter :a, type: :integer
        parameter :b, type: :integer

        def process(%{a: a, b: b}), do: a + b
      end

  By using `Exop.Callback` you need to implement `process/4` function which takes following params:
    * operation module (`TestOperation` in the example above)
    * params that were passed into the operation (`%{a: 1, b: 2}`)
    * an successful result which was returned by the operation.
    * opts is an open keyword list for metadata passing.

  Callback operation has no effect on the result. but trigger a callback after success coming handy to send
  PubSub prodcast or any side effect event without interrepting the main workflow.
  """

  @type t :: __MODULE__

  @doc """
  Callback handling function.
  Receives:
    - operation module
    - a map of parameters with which the operation was invoked
    - an result tuple returned by the operation
    - a keyword list defined as opts in within macro call.
  """

  @callback process(atom(), map(), any(), keyword() | []) :: any()

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__)
    end
  end
end
