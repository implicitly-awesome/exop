defmodule Exop.Policy do
  @moduledoc """
  Provides a few macros for policy validation.
  """

  @type t :: __MODULE__

  @callback authorize(atom, any, Keyword.t) :: true | false

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @doc "authorizes `user` possibility to invoke an `action`"
      @spec authorize(atom, any, Keyword.t) :: true | false
      def authorize(action, user, opts \\ []) do
        apply(__MODULE__, action, [user, opts]) == true
      end      
    end
  end
end