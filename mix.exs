defmodule Exop.Mixfile do
  use Mix.Project

  @description """
  A library that provides a few macros which allow
  you to encapsulate business logic and validate incoming
  params over predefined contract.
  """

  def project do
    [
      app: :exop,
      version: "1.3.0",
      elixir: ">= 1.3.0",
      name: "Exop",
      description: @description,
      package: package(),
      deps: deps(),
      source_url: "https://github.com/madeinussr/exop",
      docs: [extras: ["README.md"]],
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod
    ]
  end

  def application do
    [
      applications: [:logger]
    ]
  end

  defp deps do
    [
      {:mock, "~> 0.1", only: :test},
      {:ex_doc, "~> 0.12", only: [:dev, :test, :docs]},
      {:dialyxir, "~> 1.0.0-rc.4", only: [:dev], runtime: false}
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["Andrey Chernykh", "Aleksandr Fomin"],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/madeinussr/exop"}
    ]
  end
end
