defmodule Exop.Policy do
  @moduledoc """
  Provides macros for policy validation.

  ## Example

      defmodule MonthlyReportPolicy do
        # not only Keyword or Map as an argument since 1.1.1
        def can_read?(%{user_role: "admin"}), do: true
        def can_read?("admin"), do: true
        def can_read?(%User{role: "manager"}), do: true
        def can_read?(:manager), do: true
        def can_read?(_opts), do: false

        def can_write?(%{user_role: "manager"}), do: true
        def can_write?(_opts), do: false
      end

      defmodule ReadOperation do
        use Exop.Operation

        policy MonthlyReportPolicy, :can_read?

        parameter :user, required: true, struct: %User{}

        def process(params) do
          authorize(params.user)

          # make some reading...
        end
      end

  If authorization fails, any code after (below) auth check is postponed:
  an error `{:error, {:auth, _reason}}` is returned immediately.
  """

  @type t :: __MODULE__

  @doc """
  Authorizes the possibility to invoke an action.
  """
  @callback authorize(atom, any()) :: true | false

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @spec authorize(atom, any()) :: true | false
      def authorize(action, opts), do: apply(__MODULE__, action, [opts]) == true
    end
  end
end
