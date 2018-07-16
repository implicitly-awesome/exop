defmodule ExopPolicyTest do
  use ExUnit.Case, async: false

  defmodule TestPolicy do
    use Exop.Policy

    def can_true?(_user, _opts), do: true

    def can_false?(_user, _opts), do: false

    def can_smth?(_user, _opts), do: "just string"

    def can_error?(_user, _opts), do: raise(ArithmeticError, "oops")

    def just_opts(_user, [a: 1, b: 2] = opts), do: opts
    def just_opts(_user, _opts), do: raise "unknown opts"
  end

  defmodule TestUser do
    defstruct ~w(name email)a
  end

  test "has authorize/3 function" do
    assert Enum.member?(TestPolicy.__info__(:functions), {:authorize, 3})
  end

  test "only true is treated as true" do
    assert TestPolicy.authorize(:can_true?, %TestUser{})
    refute TestPolicy.authorize(:can_false?, %TestUser{})
    refute TestPolicy.authorize(:can_smth?, %TestUser{})
  end

  test "errors are passed through" do
    assert_raise ArithmeticError, fn ->
      TestPolicy.authorize(:can_error?, %TestUser{})
    end
  end

  test "authorize/3 pass opts to policy action" do
    assert TestPolicy.authorize(:just_opts, %TestUser{}, a: 1, b: 2) == false

    assert_raise RuntimeError, "unknown opts", fn ->
      TestPolicy.authorize(:just_opts, %TestUser{}, a: 123, b: 321)
    end
  end
end
