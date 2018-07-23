defmodule ExopPolicyTest do
  use ExUnit.Case, async: false

  defmodule User do
    defstruct ~w(name email)a
  end

  defmodule TestPolicy do
    use Exop.Policy

    def can_true?(_opts), do: true

    def can_false?(_opts), do: false

    def can_smth?(_opts), do: "just string"

    def can_error?(_opts), do: raise(ArithmeticError, "oops")

    def can_read?(%{user: %User{name: "admin"}} = _opts), do: true
    def can_read?(_opts), do: false
  end

  defmodule TestOperation do
    use Exop.Operation

    policy TestPolicy, :can_read?

    parameter :user, required: true, struct: %User{}

    def process(params) do
      authorize(user: params[:user])
      :operation_result
    end
  end

  test "has authorize/2 function" do
    assert Enum.member?(TestPolicy.__info__(:functions), {:authorize, 2})
  end

  test "only true is treated as true" do
    assert TestPolicy.authorize(:can_true?, user: %User{})
    refute TestPolicy.authorize(:can_false?, user: %User{})
    refute TestPolicy.authorize(:can_smth?, user: %User{})
  end

  test "errors are passed through" do
    assert_raise ArithmeticError, fn ->
      TestPolicy.authorize(:can_error?, user: %User{})
    end
  end

  test "TestOperation: admin user can read" do
    assert TestOperation.run(user: %User{name: "admin"}) == {:ok, :operation_result}
  end

  test "TestOperation: Not admin user can't read" do
    assert TestOperation.run(user: %User{name: "manager"}) == {:error, {:auth, :can_read?}}
  end
end
