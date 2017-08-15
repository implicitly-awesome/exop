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
