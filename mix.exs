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

      # Docs
      name: "PgMoney",
      docs: [
        extras: ["README.md"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:postgrex, ">= 0.0.0"},
      {:decimal, ">= 0.0.0"},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false}
    ]
  end
end
