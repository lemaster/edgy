# Edgy

Edgy is a set of Ecto Schema and functions for treating PostgreSQL as a graph database. You can use it with other Ecto backends but the filter by property queries will not work as they utilize the PostgreSQL jsonb operators.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `edgy` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:edgy, "~> 0.1.0"}
  ]
end
```

### Make a migration

    mix ecto.gen.migration setup_edgy

Then make the change function look like this:

```elixir
def change do
    Edgy.Migrations.run_migrations()
end
```

### Configure the default Repo

```elixir
config :edgy, repo: MyApp.Repo
```

## Usage

```elixir
{:ok, graph} = Edgy.create_graph("demo")
{:ok, a} = Edgy.add_node(graph, "node", %{name: "a"})
{:ok, b} = Edgy.add_node(graph, "node", %{name: "b"})
{:ok, c} = Edgy.add_node(graph, "node", %{name: "c"})
{:ok, ab} = Edgy.add_edge(graph, "link", %{name: "a -> b", strength: "strong"}, a, b)
{:ok, bc} = Edgy.add_edge(graph, "link", %{name: "b -> c", strength: "weak"}, b, c)

Edgy.edges([a], direction: :from, recursive: true)
Edgy.edges([a], properties: %{strength: "strong"})
Edgy.edges([a], properties: %{strength: "weak"})**TODO: Add description**
```

Once published, the docs can be found at <https://hexdocs.pm/edgy>.
