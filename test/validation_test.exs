defmodule ValidationTest do
  use ExUnit.Case, async: false

  doctest Exop.Validation

  import Exop.Validation

  defmodule TestStruct do
    defstruct ~w(a b)a
  end

  setup do
    contract = [
      %{
        name: :param,
        opts: [required: true, type: :string]
      },
      %{
        name: :param2,
        opts: [type: :integer, in: [1, 2, 3]]
      }
    ]

    %{contract: contract}
  end

  test "validate/3: returns true if item's contract has unknown check", _context do
    contract = [%{
      name: :param,
      opts: [unknown_check: "whatever"]
    }]
    assert validate(contract, %{param: "some_value"}, []) == [true, true]
  end

  test "validate/3: accumulates related checks results", %{contract: contract} do
    assert validate(contract, %{param2: "some_value"}, []) ==
      [%{param: "is required"}, true, true, %{param2: "has wrong type"}, %{param2: "must be one of [1, 2, 3]"}]
  end

  test "valid?/2: returns :ok if all params conform the contract", %{contract: contract} do
    received_params = [param: "param", param2: 2]

    assert valid?(contract, received_params) == :ok
  end

  test "valid?/2: returns {:error, :validation_failed, reasons} if at least one
        of params doesn't conform the contract", %{contract: contract} do
    received_params = [param: "param", param2: 4]

    {:error, {:validation, reasons}} = valid?(contract, received_params)
    assert is_map(reasons)
  end

  test "valid?/2: {:error, :validation_failed, reasons} reasons - is a map", %{contract: contract} do
    received_params = [param: "param", param2: "4"]

    {:error, {:validation, reasons}} = valid?(contract, received_params)
    assert is_map(reasons)
    assert reasons |> Map.get(:param2) |> is_list
    assert reasons |> Map.get(:param2) |> List.first |> is_binary
  end

  test "valid?/2: validates a parameter inner item over inner option checks" do
    contract = [
      %{name: :map_param, opts: [
        type: :map,
        inner: %{
          a: %{type: :integer},
          b: %{type: :string, length: %{min: 7}}
          }
        ]
      }
    ]

    received_params = [map_param: %{a: "2", b: "6chars"}]

    {:error, {:validation, reasons}} = valid?(contract, received_params)
    assert is_map(reasons)
    keys = Map.keys(reasons)
    assert Enum.member?(keys, "map_param[:a]")
    assert Enum.member?(keys, "map_param[:b]")
  end

  test "valid?/2: validates parent parameter itself while validating its inner" do
    contract = [
      %{name: :map_param, opts: [
        type: :map,
        inner: %{
          a: [type: :integer],
          b: [type: :string, length: %{min: 7}]
          }
        ]
      }
    ]

    received_params = [map_param: [a: "2", b: "6chars"]]

    {:error, {:validation, reasons}} = valid?(contract, received_params)
    assert is_map(reasons)
    keys = reasons |> Map.keys
    assert Enum.member?(keys, :map_param)
    assert Enum.member?(keys, "map_param[:a]")
    assert Enum.member?(keys, "map_param[:b]")
  end

  test "valid?/2: validates an inner struct parameter with inner option checks" do
    contract = [
      %{name: :map_param, opts: [
        type: :map,
        inner: %{
          a: %{type: :integer},
          b: %{type: :string, length: %{min: 7}}
        }
      ]}
    ]

    received_params = [map_param: %TestStruct{a: "2", b: "6chars"}]

    {:error, {:validation, reasons}} = valid?(contract, received_params)
    assert is_map(reasons)
    keys = Map.keys(reasons)
    assert Enum.member?(keys, "map_param[:a]")
    assert Enum.member?(keys, "map_param[:b]")
  end

  test "valid?/2: validates a list parameter items with list_item option checks (simple)" do
    contract = [
      %{
        name: :list_param,
        opts: [
          type: :list,
          list_item: %{type: :string, length: %{min: 7}}
        ]
      }
    ]

    received_params = [
      list_param: [1, "6chars", nil, "7charss"]
    ]

    {:error, {:validation, reasons}} = valid?(contract, received_params)

    assert %{
      "list_param[0]" => ["has wrong type", "length must be greater than or equal to 7"],
      "list_param[1]" => ["length must be greater than or equal to 7"],
      "list_param[2]" => ["has wrong type", "length must be greater than or equal to 7"]
    } == reasons
  end

  test "valid?/2: validates a list parameter items with list_item option checks (inner)" do
    contract = [
      %{
        name: :list_param,
        opts: [
          type: :list,
          list_item: %{inner: %{
            a: %{type: :integer},
            b: %{type: :string, length: %{min: 7}}
          }}
        ]
      }
    ]

    received_params = [
      list_param: [
        %TestStruct{a: 3, b: "6chars"},
        %TestStruct{a: "3", b: "7charss"}
      ]
    ]

    {:error, {:validation, reasons}} = valid?(contract, received_params)

    assert %{
      "list_param[0][:b]" => ["length must be greater than or equal to 7"],
      "list_param[1][:a]" => ["has wrong type"]
    } == reasons
  end

  test "valid?/2: validates a list parameter items with list_item option checks (not list)" do
    contract = [
      %{
        name: :list_param,
        opts: [
          list_item: %{type: :string, length: %{min: 7}}
        ]
      }
    ]

    received_params = [
      list_param: 1
    ]

    {:error, {:validation, reasons}} = valid?(contract, received_params)

    assert %{list_param: ["is not a list"]} == reasons
  end

  test "valid?/2: validates a list parameter items with list_item option checks (success)" do
    contract = [
      %{
        name: :list_param,
        opts: [
          list_item: %{type: :string, length: %{min: 7}}
        ]
      }
    ]

    received_params = [
      list_param: ["1234567", "7charss"]
    ]

    assert valid?(contract, received_params) == :ok
  end
end
