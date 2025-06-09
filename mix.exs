defmodule Edgy.MixProject do
  use Mix.Project

  @source_url "https://github.com/lemaster/edgy"

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
        licenses: ["MIT"],
        links: %{
          "GitHub" => @source_url
        },
        source_url: @source_url
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
      {:ecto_sql, "~> 3.12"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
