locals_without_parens = [
  parameter: 1,
  parameter: 2,
  operation: 1,
  operation: 2,
  policy: 2,
  authorize: 0,
  authorize: 1,
  fallback: 1,
  fallback: 2
]

[
  inputs: ["mix.exs", "{config,lib}/**/*.{ex,exs}"],
  line_length: 100,
  locals_without_parens: locals_without_parens,
  export: [
    locals_without_parens: locals_without_parens
  ]
]
