defmodule Edgy.MixProject do
  use Mix.Project

  def project do
    [
      app: :edgy,
      version: "1.0.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # Hex
      description: "A library on top of Ecto for using PostgreSQL as a graph database.",
      package: [
        name: :edgy,
        maintainers: ["Fred LeMaster"],
        licenses: ["MIT"]
        source_url: %{"GitHub" => "https://github.com/lemaster/edgy"}
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.12"}
    ]
  end
end
