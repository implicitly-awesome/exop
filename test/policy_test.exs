defmodule PolicyTest do
  use ExUnit.Case, async: false

  defmodule User do
    defstruct ~w(name email)a
  end

  defmodule TestPolicy do
    def can_read?(%User{name: "admin"}), do: true
    def can_read?(_opts), do: false

    def can_write?(_opts), do: ["just something", :that_will_be, {"an", :error, Reason}]

    def can_error?(_opts), do: raise(ArithmeticError, "2 + 2 != 5")
  end

  defmodule ReadOperation do
    use Exop.Operation
    policy TestPolicy, :can_read?
    parameter :user, required: true, struct: User

    def process(params) do
      authorize(params[:user])
      :read_result
    end
  end

  defmodule WriteOperation do
    use Exop.Operation
    policy TestPolicy, :can_write?
    parameter :user, required: true, struct: User

    def process(params) do
      authorize(params[:user])
      :write_result
    end
  end

  defmodule ErrorOperation do
    use Exop.Operation
    policy TestPolicy, :can_error?
    parameter :user, required: true, struct: User

    def process(params) do
      authorize(params[:user])
      :error_result
    end
  end

  defmodule CustomErrorOperation do
    use Exop.Operation
    policy TestPolicy, :can_custom_error?
    parameter :user, required: true, struct: User

    def process(params) do
      authorize(params[:user])
      :custom_error_result
    end
  end

  test "only true is treated as true" do
    assert WriteOperation.run(user: %User{name: "admin"}) ==
             {:error, {:auth, ["just something", :that_will_be, {"an", :error, Reason}]}}
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
