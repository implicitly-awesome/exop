defmodule Exop.Policy do
  @moduledoc """
  Provides macros for policy validation.

  ## Example

      defmodule MonthlyReportPolicy do
        use Exop.Policy

        def can_read?(%{user_role: "admin"}), do: true
        def can_read?(%{user_role: "manager"}), do: true
        def can_read?(_opts), do: false

        def can_write?(%{user_role: "manager"}), do: true
        def can_write?(_opts), do: false
      end

      defmodule ReadOperation do
        use Exop.Operation

        policy MonthlyReportPolicy, :can_read?

        parameter :user, required: true, struct: %User{}

        def process(%{user: %User{role: role}}) do
          authorize(user_role: role)

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
  @callback authorize(atom, Keyword.t()) :: true | false

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @spec authorize(atom, Keyword.t() | map()) :: true | false
      def authorize(action, opts \\ [])

      def authorize(action, opts) when is_list(opts) do
        opts = Enum.into(opts, %{})
        authorize(action, opts)
      end

      def authorize(action, opts) when is_map(opts) do
        apply(__MODULE__, action, [opts]) == true
      end
    end
  end
end
