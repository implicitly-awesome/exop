[![Hex.pm](https://img.shields.io/hexpm/v/exop.svg)](https://hex.pm/packages/exop) [![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](http://hexdocs.pm/exop/) [![Build Status](https://travis-ci.org/madeinussr/exop.svg?branch=master)](https://travis-ci.org/madeinussr/exop)

# Exop

A library that helps you to organize your Elixir code in more domain-driven way.
Exop provides macros which helps you to encapsulate business logic and offers you additionally:
incoming params validation (with predefined contract), params coercion, policy check, fallback behavior and more.

### ExopData

Interested in property-based testing? Check out new Exop family member - [ExopData](https://github.com/madeinussr/exop_data). If you use Exop to organize your code with ExopData you can get property generators in the most easiest way.

## Table of Contents

Here is the [CHANGELOG](https://github.com/madeinussr/exop/blob/master/CHANGELOG.md) that was started from ver. 0.4.1 ¯\\\_(ツ)\_/¯

- [Installation](#installation)
- [Operation definition](#operation-definition)
  - [Parameter checks](#parameter-checks)
    - [type](#type)
    - [required](#required)
    - [default](#default)
    - [numericality](#numericality)
    - [equals](#equals)
    - [in](#in)
    - [not_in](#not_in)
    - [format](#format)
    - [length](#length)
    - [inner](#inner)
    - [struct](#struct)
    - [list_item](#list_item)
    - [func](#func)
    - [allow_nil](#allow_nil)
    - [from](#from)
  - [Defined params](#defined-params)
  - [Interrupt](#interrupt)
  - [Coercion](#coercion)
  - [Policy check](#policy-check)
  - [Fallback module](#fallback-module)
- [Operation invocation](#operation-invocation)
- [Operation results](#operation-results)
- [Operations chain](#operations-chain)

## Installation

```elixir
def deps do
  [{:exop, "~> 1.3.1"}]
end
```

## Operation definition

```elixir
defmodule IntegersDivision do
  use Exop.Operation

  parameter :a, type: :integer, default: 1
  parameter :b, type: :integer, required: false,
                numericality: %{greater_than: 0}

  def process(params) do
    result = params[:a] / params[:b]
    IO.inspect "The division result is: #{result}"
  end
end
```

`Exop.Operation` provides `parameter` macro, which is responsible for the contract definition.
Its spec is `@spec parameter(atom | String.t, Keyword.t) :: none`, we define parameter name as the first argument and parameter options as the second `Keyword` argument.

_A parameter name could be either an atom or a string. You could even mix atom-named and string-named parameters in an operation's contract._

Parameter options determine a contract of a parameter, a set of parameters contracts is an operation contract.

Business logic of an operation is defined in `process/1` function, which is required by the Exop.Operation module
behaviour.

After the contract and business logic were defined, you can invoke the operation simply by calling `run/1` function:

```elixir
iex> IntegersDivision.run(a: 50, b: 5)
{:ok, "The division result is: 10"}
```

Return type will be either `{:ok, any()}` (where the second item in the tuple is `process/1` function's result) or
`{:error, {:validation, map()}}` (where the `map()` is validation errors map).

_for more information see [Operation results](#operation-results) section_

### Parameter checks

A parameter options could have various checks. Here the list of checks available yet:

- `type`
- `required`
- `default`
- `numericality`
- `equals` (`exactly`)
- `in`
- `not_in`
- `format` (`regex`)
- `length`
- `inner`
- `struct`
- `list_item`
- `func`
- `allow_nil`

#### `type`

Checks whether a parameter's value is of declared type.

```elixir
parameter :some_param, type: :map
```

Exop handle almost all Elixir types and some additional:

- :boolean
- :integer
- :float
- :string
- :tuple
- :map
- :keyword
- :list
- :atom
- :module
- :function
- :uuid

_Unknown type always generates ArgumentError exception on compile time._

`module` 'type' means Exop expects a parameter's value to be an atom (a module name) and this module should be already loaded (ready to call it's functions)

`uuid` is not actually a "type" but I placed this under `:type` check because there is no reason to have dedicated `:uuid` check.

#### `required`

Checks the presence/absence of a parameter in passed to `run/1` params collection.
Given parameters collection fails the validation only if required parameter is missed,
if required parameter's value is `nil` this parameter will pass this check.

```elixir
parameter :param_a                   # the same as required: true, required by default
parameter :param_b, required: false  # this parameter is not required
```

By default, a parameter is required (since version 1.2.0, `required: true`).
If you want to specify a parameter is not required, provide `required: false`.
Why? Because you might find that you repetitively type `required: true` for almost every parameter in a contract. I think if you provide a parameter to an operation (define it in a contract) you expect to get it. Cases, when you need a parameter passed into an operation (and don't really care whether it is present or not), are pretty rare.

_Since version 1.1.0 the behavior of this check has been changed. Check out CHANGELOG for more info._

#### `default`

Checks the presence of a parameter in passed to `run/1` params collection,
and if the parameter is missed - assign default value to it.

```elixir
parameter :some_param, default: "default value"
```

#### `numericality`

Checks whether a parameter's value is a number and other numeric constraints.
All possible constraints are listed in the example below.

```elixir
parameter :some_param, numericality: %{equal_to: 10, # (aliases: `equals`, `is`, `eq`)
                                       greater_than: 0, # (alias: `gt`)
                                       greater_than_or_equal_to: 10 # (aliases: `min`, `gte`),
                                       less_than: 20, # (alias: `lt`)
                                       less_than_or_equal_to: 10 # (aliases: `max`, `lte`)}
```

#### `equals`

(alias: `exactly`)

Checks whether a parameter's value exactly equals given value (with type equality).

```elixir
parameter :some_param, equals: 100.5
parameter :some_param, exactly: 100.5
```

#### `in`

Checks whether a parameter's value is within a given list.

```elixir
parameter :some_param, in: ~w(a b c)
```

#### `not_in`

Checks whether a parameter's value is not within a given list.

```elixir
parameter :some_param, not_in: ~w(a b c)
```

#### `format`

(alias: `regex`)

Checks wether parameter's value matches given regex.

```elixir
parameter :some_param, format: ~r/foo/
parameter :some_param, regex: ~r/foo/
```

#### `length`

Checks the length of a parameter's value. The value should be one of handled types:

- list (items count)
- string (chars count)
- atom (treated as string)
- map (key-value pairs count)
- tuple (items count)

`length` check is complex as `numericality` (should define map of inner checks).
All possible checks are listed in the example below.

```elixir
parameter :some_param, length: %{gte: 5, gt: 4, min: 5, lte: 10, lt: 9, max: 10, is: 7, in: 5..8}
```

#### `inner`

Checks the inner of either Map or Keyword parameter. It applies checks described in `inner` map to
related inner items.

```elixir
# some_param = %{a: 3, b: "inner_b_attr"}

parameter :some_param, type: :map, inner: %{
  a: [type: :integer],
  b: [type: :string, length: %{min: 1, max: 6}]
}

# you can omit `type` and `inner` checks keywords in order to check inner of your parameter,
# when `type` hasn't been specified explicitly, both keyword and map types pass the `type` validation
parameter :some_param, %{
  a: [type: :integer],
  b: [type: :string, length: %{min: 1, max: 6}]
}
```

And, of course, all checks on a parent parameter (`:some_param` in the example) are still applied.

#### `struct`

Checks whether the given parameter is expected structure.

```elixir
parameter :some_param, struct: %SomeStruct{}
# or
parameter :some_param, struct: SomeStruct
```

#### `list_item`

Checks whether each of list items conforms defined checks.
An item's checks could be any that Exop offers:

```elixir
# list_param = ["1234567", "7chars"]

# you can omit `type` check while you're passing a list to an operation
parameter :list_param, list_item: %{type: :string, length: %{min: 7}}
```

Even more complex like `inner`:

```elixir
# list_param = [
#   %TestStruct{a: 3, b: "6chars"},
#   %TestStruct{a: nil, b: "7charss"}
# ]

parameter :list_param, list_item: %{inner: %{
                                              a: %{type: :integer},
                                              b: %{type: :string, length: %{min: 7}}
                                            }}
```

Moreover, `coerce_with` and `default` options are available too.

#### `func`

Checks whether an item is valid over custom validation function.
If this function returns `false`, validation will fail with default message `"isn't valid"`.

```elixir
# arity of 1
parameter :some_param, func: &is_atom/1

# arity of 2
parameter :some_param, func: &__MODULE__.your_validation/2

def your_validation(_params, param_value), do: !is_nil(param_value)

# arity of 3

parameter :some_param, func: &__MODULE__.your_validation/3

def your_validation(_params, :some_param = _param_name, param_value), do: !is_nil(param_value)
```

A custom validation function can also return a user-specified message which will be displayed in map of validation errors.

```elixir
def your_validation(_params, param) do
  if param > 99 do
    true
  else
    {:error, "Custom error message"}
  end
end
```

Therefore, validation will fail, if the function returns either `false` or `{:error, your_error_msg}` tuple.

`func/1` receives one argument which is the actual parameter value to check.

`func/2` receives two arguments: the first is a contract of an operation (parameters with their values),
the second - the actual parameter value to check. So, now you can validate a parameter depending on other parameters values.

```elixir
parameter :a, type: :integer
parameter :b, func: &__MODULE__.your_validation/2

def your_validation(params, b), do: params[:a] > 0 && !is_nil(b)
```

_it's possible to combine :func check with others (though not preferable), just make sure this check is the last check in the list_

#### allow_nil

It is a parameter attribute which allow you to have other checks for a parameter whilst have a possibility to pass `nil` as the parameter's value.
If `allow_nil: true` and `nil` is passed as a parameter value _all_ the parameter's checks are ignored during validation.

```elixir
defmodule YourOperation do
  use Exop.Operation

  parameter :a, type: :integer, allow_nil: true
  parameter :b, type: :integer, allow_nil: false

  def process(params), do: params
end

{:ok, %{a: 1, b: 1}} = YourOperation.run(a: 1, b: 1)
{:ok, %{a: nil, b: 1}} = YourOperation.run(a: nil, b: 1)
{:error, {:validation, %{b: ["doesn't allow nil"]}}} = YourOperation.run(a: nil, b: nil)
```

_By default (if you omit `allow_nil`), a parameter is treated as `allow_nil: false`_

#### from

This option allows you to pass a parameter to `run/1` and `run!/1` functions with one name and work with this parameter within an operation under another name.

```elixir
defmodule YourOperation do
  use Exop.Operation

  parameter :a, type: :integer, from: "a"
  parameter :b, type: :string, from: :bB

  def process(params), do: params
end

# now you can invoke YourOperation with such params:
#   Youroperation.run(%{"a" => 1, b: "1"})
#   Youroperation.run(%{a: 1, bB: "1"})
#   Youroperation.run(%{"a" => 1, bB: "1"})
# and get:
#   {:ok, %{a: 1, b: "1"}}
```

The same works for parameters given as a Keyword as well (in this case `:from` value should be an atom):

```elixir
defmodule YourOperation do
  use Exop.Operation

  parameter :a, type: :integer, from: :aA
  parameter :b, type: :string, from: :bB

  def process(params), do: params
end

# Youroperation.run(a: 1, b: "1")
# Youroperation.run(aA: 1, bB: "1")
# {:ok, %{a: 1, b: "1"}}
```

Why? Simply because sometimes you're not in control of incoming parameters but don't want to map them each time you need to use'em by yourself (good example: params in Phoenix controller's action, which come as a map with string keys).

_This option doesn't work for `:inner` check's inner parameters currently._

### Interrupt

In some cases you might want to make an 'early return' from `process/1` function.
For this purpose you can call `interrupt/1` function within `process/1` and pass an interruption reason to it.
An operation will be interrupted and return `{:interrupt, your_reason}`

```elixir
# ...
def process(_params) do
  interrupt(%{fail: "oops"})
  :ok # will not return it
end
# ...

SomeOperation.run(a: 1) # {:interrupt, %{fail: "oops"}}
```

_`run!/1` invocation doesn't affect interruption result: {:interrupt, \_your_result} tuple will be returned anyway as expected and handled result._

### Coercion

It is possible to coerce a parameter before the contract validation, all validation checks
will be invoked on coerced parameter value.
Since coercion changes a parameter before any validation has been invoked,
default values are resolved (with `:default` option) before the coercion.
The flow looks like: `Resolve param default value -> Coerce -> Validate coerced`

If coercion function returns an error tuple it will be treated as validation failure: an operation's invokation stops and that error tuple will be returned as a result.

`:coerce_with` accepts 2-arity function. This function takes a tuple `{coerced_param_name, coerced_param_value}` as the first argument and a map with all the parameters that have been passed to either `run/1` or `run!/1` function as the second argument.

```elixir
parameter :a, type: :integer
parameter :b, type: :string, coerce_with: &__MODULE__.to_string/2
parameter :c, type: :string, coerce_with: &__MODULE__.to_string/2

def to_string({_, value}, %{a: _, b: _, c: _} = _received_params) when is_integer(value) do
  Integer.to_string(c_value)
end

def to_string({_, value}, _received_params) when is_binary(c_value) do
  value
end

def to_string({:c, c_value}, _received_params) do
  # special coercion for :c parameter here
end
```

_Why it is so? Because there are cases when you can use the same coercion function for multiple params and/or coerce a parameter depending on another's value and need to have all this information._

### Policy check

It is possible to define a policy that will be used for authorizing the possibility to invoke an operation. So far, there is a simple policy implementation and usage:

- first of all, define a policy module _(`use Exop.Policy` is not actual since ver. 1.1.1 - it is not mandatory to use this macro. Just define a module with a bunch of functions that take a single argument (any type) and return either true or false)_

```elixir
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
```

In this policy two actions (checks) defined (`can_read?/1` & `can_write?/1`).
Every action expects an argument for a check. It's up to you how to handle this argument and turn it into the actual check.

_Bear in mind: only `true` return-value treated as true, everything else returned form an action treated as false_

- next step - link an operation and a policy

```elixir
  defmodule ReadOperation do
    use Exop.Operation

    policy MonthlyReportPolicy, :can_read?

    parameter :user, struct: %User{}

    def process(%{user: %User{} = user}) do
      # make some reading...
    end
  end
```

- finally - call `authorize/1` within `process/1`

```elixir
  defmodule ReadOperation do
    use Exop.Operation

    policy MonthlyReportPolicy, :can_read?

    parameter :user, struct: %User{}

    def process(params) do
      authorize(params.user)

      # make some reading...
    end
  end
```

_Please, note: if authorization fails, any code after (below) auth check
will be postponed (an error `{:error, {:auth, _policy_action_name}}` will be returned immediately as an operation result)_

### Fallback module

If you'd like to handle various operations fails with a certain logic (for example log it into Graylog)
you can use `Exop.Fallback`.

Define a fallback module:

```elixir
  defmodule FallbackModule do
    use Exop.Fallback

    def process(operation, params, error) do
      # your error handling code here
      :some_fallback_result
    end
  end
```

here you need to define and implement `process/3` function which takes following params:

- failed operation module
- params that were passed into the operation
- an error result which was returned by the operation

Use your fallback in operations like this:

```elixir
defmodule SomeOperation do
  use Exop.Operation

  fallback FallbackModule, return: true

  parameter :a, type: :integer
  parameter :b, type: :integer

  def process(%{a: a, b: b}), do: a + b
end
```

The results of the operation executions:

```elixir
# SomeOperation will fail
iex> SomeOperation.run(a: 1, b: "2")
:some_fallback_result

# SomeOperation will be successful
iex> SomeOperation.run(a: 1, b: 2)
{:ok, 3}
```

During a fallback definition you can add `return: true` option so in the example case
`SomeOperation.run/1` will return the result of the fallback (`FallbackModule.process/3`
function's result - `:some_fallback_result`).
If you want `SomeOperation.run/1` to return original result (`{:error, {:validation, %{a: ["has wrong type"]}}}`)
specify `return: false` option or just omit it in a fallback definition.

## Operation invocation

As said earlier, operations in most cases called by `run/1` function. This function
receives parameters collection. It's not required to pass to `run/1` function parameters
only described in the operation's contract, but only described parameters will be validated and gived to `process/1` function, all other will be filtered out from the process.

_filtering out parameters which are not defined in a contract is here to support the whole idea of defining the right operation's contract and take care of what you really need for a certain business process / function_

`run/1` function validates received parameters over the contract and if all parameters passed
the validation, the `run/1` function calls the code defined in `process/1` function.

```elixir
iex> SomeOperation.run(param1: 1, param2: "2")
_some_result_
```

If at least one of the given parameters didn't pass the validation `process/1` function's code
will not be invoked and corresponding warning in the application's log will appear.

There is "bang" version of `run/1` exists. Function `run!/1` does the same things that its sibling does,
the only difference is a result of invocation, it might be:

- if a contract validation passed - the actual result of an operation (result of a code, described in `process/1`)
- if a contract validation failed - an error `Exop.Validation.ValidationError` raising
- in case of manual interruption - `{:interrupt, _reason}`

_You always can bypass the validation simply by calling `process/1` function itself, if needed._

## Operation results

If received parameters passed a contract validation, a code defined in `process/1` will be invoked.
Or you will receive `@type validation_error :: {:error, :validation_failed, map()}` as a result otherwise.
`map()` as errors reasons might look like this:

```elixir
%{param1: ["has wrong type"], param2: ["is required", "must be equal to 3"]}
```

An operation can return one of results listed below (depends on passed in params and operation definition):

- an operation was completed successfully:
  - `{:error, _your_error_reason_}` (if an :error-tuple (any length, but `:error` atom should be the first element) was returned by `process/1` function)
  - `{:ok, any()}` (otherwise, even if `{:ok, _your_result_}` tuple was returned by `process/1` function)
- a contract validation failed: `{:error, {:validation, map()}}`
- if `interrupt/1` was invoked: `{:interrupt, any()}`
- policy check failed:
  - `{:error, {:auth, :undefined_policy}}`
  - `{:error, {:auth, :undefined_action}}`
  - `{:error, {:auth, atom()}}`

_For the "bang" version of `run/1` see results description above._

## Operations chain

Sometimes you need to aggregate/group 'atom' operations into a single one operation responsible for
some complex business process/logic.
You have a few approaches to do it (`with` for example) but mb you'll find `Exop.Chain` more handy.

`Exop.Chain` provides a simple way to organize a number of Exop.Operation modules into an invocation chain.

```elixir
defmodule CreateUser do
  use Exop.Chain

  alias Operations.{User, Backoffice, Notifications}

  operation User.Create
  operation Backoffice.SaveStats
  operation Notifications.SendEmail

  # or you can use step alias:
  #   step User.Create
  #   step Backoffice.SaveStats
  #   step Notifications.SendEmail
end
```

This is how invoke this chain:

```elixir
iex> CreateUser.run(name: "User Name", age: 37, gender: "m")
```

`Exop.Chain` defines `run/1` function under the hood (like common operations do) that accepts `keyword()`, `map()` or `struct()` as params.
Those params will be passed into the first operation in the chain.
Bear in mind that each of chained operations (except the first one) awaits a returned result of
a previous operation as incoming params.

So in the example above `CreateUser.run(name: "User Name", age: 37, gender: "m")` will invoke
the chain by passing `[name: "User Name", age: 37, gender: "m"]` params to the first `User.Create` operation.
The result of `User.Create` operation will be passed to `Backoffice.SaveStats`
operation as its params and so on.

Once any of operations in the chain returns non-ok-tuple result (error result, interruption, auth error etc.)
the chain execution interrupts and error result returned (as the chain (`CreateUser`) result).

You can pass additional parameters to any operation in a chain (with either an exact value or 0-arity function):

```elixir
defmodule CreateUser do
  use Exop.Chain

  alias Operations.{User, Backoffice, Notifications}

  operation User.Create
  operation Backoffice.SaveStats, logger: MyFancyLoggerModule
  # or
  operation Backoffice.SaveStats, logger: &__MODULE__.logger/0
  operation Notifications.SendEmail

  def logger, do: MyFancyLoggerModule
end
```

`use Exop.Chain` can take `:name_in_error` option, when it is set to `true` a failed operation in a chain returns the operation's module name as the first elements of output tuple `{YourOperation, {:error, _}}`

```elixir
defmodule YourChain do
  use Exop.Chain, name_in_error: true

  operation Op1
  operation Op2Fail
  operation Op3
end

iex> YourChain.run(a: "1", b: 2)
{Op2Fail, {:error, {:validation, %{a: ["has wrong type"]}}}}
```

`name_in_error: true` doesn't affect operations with a fallback defined (unmodified fallback result is returned).

## LICENSE

    Copyright © 2016 - 2019 Andrey Chernykh ( andrei.chernykh@gmail.com )

    This work is free. You can redistribute it and/or modify it under the
    terms of the MIT License. See the LICENSE file for more details.
