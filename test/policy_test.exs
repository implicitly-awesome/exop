defmodule PolicyTest do
  use ExUnit.Case, async: false

  defmodule User do
    defstruct ~w(name email)a
  end

  defmodule TestPolicy do
    def can_read?(%User{name: "admin"}), do: true
    def can_read?(_opts), do: false

    def can_write?(_opts), do: "just string"

    def can_error?(_opts), do: raise(ArithmeticError, "2 + 2 != 5")
  end

  defmodule ReadOperation do
    use Exop.Operation
    policy TestPolicy, :can_read?
    parameter :user, required: true, struct: %User{}

    def process(params) do
      authorize(params[:user])
      :read_result
    end
  end

  defmodule WriteOperation do
    use Exop.Operation
    policy TestPolicy, :can_write?
    parameter :user, required: true, struct: %User{}

    def process(params) do
      authorize(params[:user])
      :write_result
    end
  end

  defmodule ErrorOperation do
    use Exop.Operation
    policy TestPolicy, :can_error?
    parameter :user, required: true, struct: %User{}

    def process(params) do
      authorize(params[:user])
      :error_result
    end
  end

  describe "new style policy" do
    test "only true is treated as true" do
      assert WriteOperation.run(user: %User{name: "admin"}) == {:error, {:auth, :can_write?}}
    end

    test "errors are passed through" do
      assert_raise ArithmeticError, fn ->
        ErrorOperation.run(user: %User{name: "admin"})
      end
    end

    test "ReadOperation: admin user can read" do
      assert ReadOperation.run(user: %User{name: "admin"}) == {:ok, :read_result}
    end

    test "ReadOperation: Not admin user can't read" do
      assert ReadOperation.run(user: %User{name: "manager"}) == {:error, {:auth, :can_read?}}
    end
  end

  defmodule LegacyPolicy do
    use Exop.Policy

    def can_true?(_opts), do: true

    def can_false?(_opts), do: false

    def can_smth?(_opts), do: "just string"

    def can_error?(_opts), do: raise(ArithmeticError, "oops")

    def can_read?(%User{name: "admin"}), do: true
    def can_read?(_opts), do: false
  end

  defmodule LegacyReadOperation do
    use Exop.Operation
    policy LegacyPolicy, :can_read?
    parameter :user, required: true, struct: %User{}

    def process(params) do
      authorize(params[:user])
      :read_result
    end
  end

  describe "legacy policy" do
    test "legacy policy: has authorize/2 function" do
      assert Enum.member?(LegacyPolicy.__info__(:functions), {:authorize, 2})
    end

    test "legacy policy: only true is treated as true" do
      assert LegacyPolicy.authorize(:can_true?, user: %User{})
      refute LegacyPolicy.authorize(:can_false?, user: %User{})
      refute LegacyPolicy.authorize(:can_smth?, user: %User{})
    end

    test "legacy policy: errors are passed through" do
      assert_raise ArithmeticError, fn ->
        LegacyPolicy.authorize(:can_error?, user: %User{})
      end
    end

    test "LegacyReadOperation: admin user can read" do
      assert LegacyReadOperation.run(user: %User{name: "admin"}) == {:ok, :read_result}
    end

    test "LegacyReadOperation: Not admin user can't read" do
      assert LegacyReadOperation.run(user: %User{name: "manager"}) == {:error, {:auth, :can_read?}}
    end
  end
end
