defmodule Exop.Mixfile do
  use Mix.Project

  @description """
  Little library that provides a few macros which allow
  you to encapsulate business logic and validate incoming
  params over predefined contract.
  """

  def project do
    [
      app: :exop,
      version: "0.2.1",
      elixir: "~> 1.3",
      name: "Exop",
      description: @description,
      package: package,
      deps: deps,
      source_url: "https://github.com/madeinussr/exop",
      docs: [extras: ["README.md"]]
   ]
  end

  def application do
    [
      applications: [:logger]
    ]
  end

  defp deps do
    [
      {:mock, "~> 0.1.1", only: :test},
      {:ex_doc, "~> 0.12", only: [:dev, :test, :docs]}
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["Andrey Chernykh"],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/madeinussr/exop"}
    ]
  end
end
