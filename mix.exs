defmodule PgMoney.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :pg_money,
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      # Docs
      name: "PgMoney",
      description: description(),
      docs: [
        extras: [
          "README.md",
          "DETAILS.md"
        ]
      ],
      #
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:postgrex, ">= 0.0.0"},
      {:decimal, ">= 0.0.0"},
      {:telemetry, "~> 0.4.0"},
      {:propcheck, "~> 1.1", only: [:test, :dev]},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:credo, "~> 1.1.0", only: [:dev, :test], runtime: false},
      {:elixir_uuid, "~> 1.2", only: [:test, :dev]}
    ]
  end

  defp package() do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE-2.0.txt", "DETAILS.md"],
      maintainers: ["Michael J. Lüttjohann"],
      licenses: ["Apache 2.0"],
      links: %{}
    ]
  end

  defp description(),
    do: """
    Adds support for PostgreSQL's money data type.
    """
end
