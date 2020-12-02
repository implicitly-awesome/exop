## [1.4.3] - yyyy.MM.dd

- not properly functioning check (since elixir 1.11.0) for struct parameters has been removed

## [1.4.2] - 2020.09.21

- a bug in `coerce_with/2` was fixed: a parameter got coerced (as `nil`) even if it is not required
- `run!` raises an `Exop.Operation.ErrorResult` error when an operation returns an error tuple

## [1.4.1] - 2020.06.08

- `Code.ensure_compiled/1` instead of deprecated `Code.ensure_compiled?/1`
- `:struct` check's bug fixed (when a value to be checked is not a struct itself)

## [1.4.0] - 2020.02.28

**breaking changes in this version!**

- a validation `type: :struct` that had been deprecated since ver. 1.2.2 was finally removed
- the `func` check's callback arguments now aligned with `coerce_with` callback, they are: a parameter's name/value tuple (the first), all parameters map given to an operation (the second), the output of the validation callback fuction has been updated as well (check README for details)
- `Exop.Chain`'s `operation` (`step`) now can be conditional with `if: _your_condition_func/1` option provided (see README for the details)
- `Exop.Chain`'s `operation` now can coerce incoming parameters with `coerce_with: your_coerce_func/1` option before any further checks/invocations

## [1.3.5] - 2019.12.27

- basic validation message extension with "got:" (credits to https://github.com/sgilson)
makes error-tuple messages more descriptive
- new `:subset_of` check allows you to check whether a given list is a subset of defined check-list

## [1.3.4] - 2019.09.18

- a bug in `coerce_with/2` refactored behavior was fixed

## [1.3.3] - 2019.09.10

- the issue with `coerce_with/2` within an `inner` check has been fixed (coercion simply didn't work in inner)
- parameters `:default` option now accepts 1-arity function as well as a certain value (see README)

## [1.3.2] - 2019.07.31

- got rid some dialyzer warnings
- specs for macros were added
- Exop.Policy module has been removed because simplified policy check is here since v1.1.1
- if Exop.Policy action returns something different from either `true` or `false`, this output is treated as authorization error message (reason)
- behaviour of unknown struct checks has been changed. Now it generates ArgumentError exception on compile time if struct parameter is not existing struct.

## [1.3.1] - 2019.06.11

- `allow_nil` check behavior bug has been fixed (default value and validations skipping)

## [1.3.0] - 2019.05.28

**breaking changes in this version!**

- Exop supports elixir >= 1.6.0
- behaviour of unknown type checks has been changed. Now it generates ArgumentError exception on compile time if type check is not supported.
- `YourOperation.run/1` now accepts structs as well as keywords and maps
- implicit inner: now you can omit `type` and `inner` checks keywords in order to check inner of your parameter
- ex_doc 0.20 (better docs)
- `:from` parameter option to be able pass one name of a parameter and work with it within an operation under another name
- new checks for `:length`: `gte`, `gt`, `lte`, `lt`
- `:length` doesnt work with numbers anymore
- `:length` and `:numericality` checks return an error for unsupported types (previously unsupported type passed the check)
- `:coerce_with` now accepts only a 2-arity function with a coerced param tuple and a map of all received params (see README for more info)
- `defined_params/1` function has been removed, now `process/1` function takes only parameters defined in a operation's contract. You still can pass any parameters in `run/1` or `run!/1` but Exop will proceed only with parameters declared in the contract

## [1.2.5] - 2019.04.11

### Changes

- allow to pass function of arity one to `func` validation

## [1.2.4] - 2019.03.28

### Changes

- `use Exop.Chain` now accepts `:name_in_error` option: when it is set to `true` a failed operation in a chain returns the operation's module name as the first elements of output tuple `{YourOperation, {:error, _}}`
- new `type: :uuid` check which supports both UUID1 and UUID4
- new aliases for `:numericality` check (to make your code slim): `:eq, :gt, :gte, :lt, :lte`
- `:inner` check now accepts opts as both map and keyword (earlier only map has been allowed)
- a few macros (like `parameter`, `operation` etc.) `locals_without_parens` formatter rule has been exported. Place `import_deps: [:exop]` into your project's `.formatter.exs` file in order to use it.
- `step/2` has been added as an alias for `Exop.Chain`'s `operation/2` macro

## [1.2.3] - 2019.02.06

### Changes

- `Exop.Chain` bug  was fixed (the last operation in a chain returned a result not wrapped into ok-tuple)
- `Exop.Chain` allows now to pass additional parameters to any operation in a chain

## [1.2.2] - 2019.01.25

### Changes

- `list_item` check allows you to omit `type` check definition, in this case `list_item` checks for the list type under the hood
- `struct` type check is deprecated
- `required: false` + `allow_nil: false` behavior has been fixed
- `type: :struct` check has been revised

## [1.2.1] - 2018.12.09

### Changes

- you get a warning if there is no any `parameter` definition
- `inner` check allows you to omit `type` check definition, in this case `inner` checks for an appropriate type (either Map or Keyword) under the hood
- `inner` returns an item's error as `"a[:c]" => ["is required"]`
- `:keyword` option for `type` check has been added
- it is allowed now to pass just a module (atom like `MyStruct`) to `struct` check, not only `%MyStruct{}`

## [1.2.0] - 2018.11.17

### Changes

- **breaking:** `required` has `true` value by default, so paramter is required by default if only you haven't specify `required: false` (a bit more info in the [README](https://github.com/madeinussr/exop#required))
- `list_item` now accept both: Map and Keyword as items checks
- `list_item` returns an item's error as `"list_param[index]" => [error_messages]`
- `:module` option for `type` check (if you want to be more explicit)
- Checks list as links in the README

## [1.1.4] - 2018.10.24

### Changes

- new `allow_nil` attribute for a parameter which allows you to pass `nil` as a parameter's value (and omit all validation checks invokation)
- a few (`min`, `max`, `is`) aliases were added to `numericality` check
- `coerce_with` now respects error tuple which might be returned from coerce function (that error tuple is returned as an operation's result immediately)

## [1.1.3] - 2018.10.02

### Changes

- a bug with `type` check was fixed: previously this check passed if a parameter's value is `nil`, now `nil` passes the check only if `:atom` type is specified

## [1.1.2] - 2018.10.01

### Changes

- now it is possible to return an :error-tuple of any length from an operation. Previously only a tuple
  of two elements was treated as error result, any other results treated as success and were wrapped into :ok-tuple
- now it is possible to provide 3-arity function to the `func` check: in previous verisons this check expected only a function with arity == 2 to invoke for checking (1. params passed to an operation, 2. param to check value), starting from this version you can provide a function with arity == 3 (in this case Exop will invoke your function with: 1. params passed to an operation, 2. param to check name, 3. param to check value)
- `coerce_with` can take a function of arity == 2 (not only with arity == 1), coercion function/2 will be invoked with args: 1. parameter name 2. parameter value (coercion function with arity == 1 still takes just a parameter value)
- some checks aliases were added

## [1.1.1] - 2018.09.20

### Changes

- some dialyzer warnings were fixed
- `in` & `not_in` checks error message fix (for example, atoms list displays as atoms list :) )
- you can now name your parameters with strings, not only atoms and even combine string- and atom-named parameters
- a policy action argument now can be a value of any type (previously only map was allowed)
- there is no need to use `Exop.Policy` in a policy module anymore (you still can use it and there is no need to rewrite exsisting policies): simply define a module with policy checks (actions) functions which are expected to take a single argument (any type) and return either `true` or `false`

## [1.1.0] - 2018.09.03

### Changes

- `required` check was revised. Now `nil` is treated as a value. It means that before this version
  `required` check returned an error if a parameter had a `nil` value. From this version
  this check fails only if parameter wasn't provided to an operation.

  To simulate previous behaviour (if you need to keep backward compatibility with parameters passed into an operation)
  you can do:

  ```elixir
  parameter :a, required: true, func: &__MODULE__.old_required/2

  def old_required(_params, nil), do: {:error, "is required"}
  def old_required(_params, param), do: true
  ```

- `ValidationError` now has an operation name in its message (better for debugging and logging)

## [1.0.0] 🎉 - 2018.07.25

### Changes

A bunch of changes were made in this release with some brand new functionality,
so I decided to bump version to 1.0.0, finally.
Exop has been working since 2016 on various projects, in production.
I think it means something and I can say it is production-ready :)

- `Exop.Chain` helps you to organize a number of operations into an invocation chain
- `Exop.Fallback` handles your operations fails (error-tuple results)
- `Exop.Policy` was simplified
- minor codebase updates
- docs were reviewed

## [0.5.1] - 2018.07.16

### Changes

- An operation's `process/1` now takes a map of parameters (contract) instead of a keywords list
  (This will help you to pattern-match them)
- Credo was wiped out (with annoying warning on `@lint`)
- Code was formatted with elixir formatter

## [0.5.0] - 2018.02.22

### Changes

- New `list_item` parameter check.

## [0.4.8] - 2017.12.28

### Changes

- Fixed `required` check when a struct was checked with `inner`.

## [0.4.7] - 2017.11.29

### Changes

- Fixed `required` check when `false` was treated as the absence of a parameter.

## [0.4.6] - 2017.10.20

### Changes

- Does not validate nil parameters if they are not required. For example:

  ```elixir
  defmodule Operation do
    use Exop.Operation

    parameter :value, type: %MyStruct{}

    # ...
  end

  # Old versions
  Operation.run([]) # {:error, {:validation, %{value: ["is not expected struct"]}}

  # This version
  Operation.run([]) # {:ok, ...}
  ```

  In previous versions such code returns validation error, because `nil` is not a `MyStruct` struct (even if it is not required by default).

  In current version such behaviour is fixed and Exop will not run validations for nil parameters if they are not required.

## [0.4.5] - 2017.08.15

### Changes

- `equals` check:
  Checks whether a parameter's value exactly equals given value (with type equality).

  ```elixir
  parameter :some_param, equals: 100.5
  ```

## [0.4.4] - 2017.06.28

### Changes

- `run/1` output:
  If your `process/1` function returns a tuple `{:ok, _your_result_}` Exop will not wrap this output into former `{:ok, _output_}` tuple.

  So, if `process/1` returns `{:ok, :its_ok}` you'll get exactly that tuple, not `{:ok, {:ok, :its_ok}}`.

  (`run!/1` acts in the same manner with respect of it's bang nature)

## [0.4.3] - 2017.06.15

### Changes

- Log improvements:
  Logger provides operation's module name if a contract validation failed. Like:
  ```
  14:21:05.944 [warn]  Elixir.ExopOperationTest.Operation errors:
  param1: has wrong type
  param2: has wrong type
  ```
- Docs
  ExDocs (hex docs) were mostly provided.
  Will be useful for some IDEs/editors plugins usage (with docs helpers) and Dash users (like me).

## [0.4.2] - 2017.05.30

### Changes

- `func/2` check:
  Custom validation function now receives two arguments: the first is a contract of an operation (parameters with their values),
  the second - the actual parameter value to check. So, now you can validate a parameter depending on other parameters values.

## [0.4.1] - 2017.05.29

### Changes

- `func/1` check:
  You can provide your error message if custom validation function returns `{:error, "Your validation message"}`.
  In other cases `false` is treaded as validation fail with default message `"isn't valid"`, everything else - validation success.
- `run/1` output:
  If your `process/1` function returns a tuple `{:error, _error_reason_}` Exop will not wrap this output into former `{:ok, _output_}` tuple.

  So, if `process/1` returns `{:error, :ugly_error}` you'll get exactly that tuple, not `{:ok, {:error, :ugly_error}}`.

  (`run!/1` acts in the same manner with respect of it's bang nature (will return unwrapped value, an exception or your error tuple))
