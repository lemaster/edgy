defmodule Edgy do
  @moduledoc """
  Documentation for `Edgy`.

  Edgy is a set of Ecto Schema and functions for treating PostgreSQL
  as a graph database. You can use it with other Ecto backends but the
  filter by property queries will not work as they utilize the
  PostgreSQL jsonb operators.

  # Installation

  ## Make a migration

      mix ecto.gen.migration setup_edgy

  Then make the change function look like this:

      def change do
          Edgy.Migrations.run_migrations()
      end

  ## Configure the default Repo

      config :edgy, repo: MyApp.Repo

  # Usage

      {:ok, graph} = Edgy.create_graph("demo")
      {:ok, a} = Edgy.add_node(graph, "node", %{name: "a"})
      {:ok, b} = Edgy.add_node(graph, "node", %{name: "b"})
      {:ok, c} = Edgy.add_node(graph, "node", %{name: "c"})
      {:ok, ab} = Edgy.add_edge(graph, "link", %{name: "a -> b", strength: "strong"}, a, b)
      {:ok, bc} = Edgy.add_edge(graph, "link", %{name: "b -> c", strength: "weak"}, b, c)

      Edgy.edges([a], direction: :from, recursive: true)
      Edgy.edges([a], properties: %{strength: "strong"})
      Edgy.edges([a], properties: %{strength: "weak"})


  # Common options:
    The query functions all accept the following options

   - `repo` - pass an explicit repo to the function otherwise the Application.env value for :edgy, :repo will be used
   - `type` - filter nodes or edges based on their type
   - `properties` - filter nodes or edges based on their properties

  """

  import Ecto.Query

  alias Edgy.Graph
  alias Edgy.Node
  alias Edgy.Edge

  @doc """
  Create a new graph. Names for graphs must be unique because we
  interact with the graph via its name.
  """
  def create_graph(name, opts \\ []) when is_binary(name) do
    repo = fetch_repo(opts)

    %Graph{}
    |> Graph.changeset(%{name: name})
    |> repo.insert()
  end

  @doc """
  Get graph by name.
  """
  def get_graph(name, opts \\ []) when is_binary(name) do
    repo = fetch_repo(opts)
    repo.one(from(g in Graph, where: g.name == ^name))
  end

  @doc """
  Delete a graph by name. Deleting a graph will delete all the associated nodes and edges.
  """
  def delete_graph(name, opts \\ []) when is_binary(name) do
    repo = fetch_repo(opts)
    repo.delete_all(from(g in Graph, where: g.name == ^name))
  end

  @doc """
  Rename a graph.
  """
  def rename_graph(%Graph{} = graph, name, opts \\ []) when is_binary(name) do
    repo = fetch_repo(opts)

    graph
    |> Graph.changeset(%{name: name})
    |> repo.update()
  end

  @doc """
  Load a full graph into memory
  """
  def load_graph(name, opts \\ []) when is_binary(name) do
    repo = fetch_repo(opts)

    repo.one(from(g in Graph, where: g.name == ^name, preload: [:nodes, :edges]))
  end

  @doc """
  Convert the graph into the data structure from the `:digraph` module.
  """
  def to_digraph(%Graph{} = graph, opts \\ []) do
    repo = fetch_repo(opts)
    digraph_type = Keyword.get(opts, :digraph_type, [:cyclic, :protected])

    graph = repo.preload(graph, [:nodes, :edges])
    node_map = Map.new(graph.nodes, fn n -> {n.id, n} end)
    edge_map = Map.new(graph.edges, fn e -> {e.id, e} end)

    dg = :digraph.new(digraph_type)
    Enum.each(graph.nodes, fn n -> :digraph.add_vertex(dg, n) end)

    Enum.each(graph.edges, fn e ->
      :digraph.add_edge(dg, node_map[e.from_id], node_map[e.to_id])
    end)

    {dg, node_map, edge_map}
  end

  @doc """
  Add a node to the graph.
  """
  def add_node(%Graph{} = graph, type, %{} = properties, opts \\ []) when is_binary(type) do
    repo = fetch_repo(opts)

    %Node{}
    |> Node.changeset(%{graph_id: graph.id, type: type, properties: properties})
    |> repo.insert()
  end

  @doc """
  Add many nodes in a single transaction.
  """
  def add_nodes(%Graph{} = graph, nodes, opts \\ []) do
    repo = fetch_repo(opts)

    repo.transaction(fn ->
      nodes
      |> Enum.map(fn {type, properties} ->
        %Node{}
        |> Node.changeset(%{graph_id: graph.id, type: type, properties: properties})
        |> repo.insert!()
      end)
    end)
  end

  @doc """
  Load nodes of a specific type from the graph. Optionally filter on the properties of the nodes.
  """
  def get_nodes(%Graph{} = graph, opts \\ []) do
    repo = fetch_repo(opts)
    type = Keyword.get(opts, :type)
    props = Keyword.get(opts, :properties)

    from(n in Node)
    |> filter_by_graph_id(graph.id)
    |> filter_by_type(type)
    |> filter_by_properties(props)
    |> repo.all()
  end

  @doc """
  Delete a node. Deleting a node will delete all edges connected to a node.
  """
  def delete_node(%Node{} = node, opts \\ []) do
    repo = fetch_repo(opts)

    repo.delete(node)
  end

  @doc """
  Delete many nodes. Deleting a node will delete all edges connected to a node.
  """
  def delete_nodes(nodes, opts \\ []) do
    repo = fetch_repo(opts)
    ids = node_ids(nodes)
    repo.delete_all(from(n in Node, where: n.id in ^ids))
  end

  @doc """
  Update the properties of a node.
  """
  def update_node(%Node{} = node, %{} = properties, opts \\ []) do
    repo = fetch_repo(opts)

    node
    |> Node.changeset(%{properties: properties})
    |> repo.update()
  end

  @doc """
  Add an edge connecting two nodes.
  """
  def add_edge(graph, type, properties, from, to, opts \\ [])

  def add_edge(_graph, _type, _properties, from, to, _opts) when from == to do
    {:error, "Cannot add an edge connecting a node to itself"}
  end

  def add_edge(
        %Graph{} = graph,
        type,
        %{} = properties,
        %Node{} = from_node,
        %Node{} = to_node,
        opts
      ) do
    repo = fetch_repo(opts)

    attrs = %{
      graph_id: graph.id,
      type: type,
      properties: properties,
      from_id: from_node.id,
      to_id: to_node.id
    }

    %Edge{}
    |> Edge.changeset(attrs)
    |> repo.insert()
  end

  @doc """
  Add a bunch of edges. `edges` should be `{type, properties, from_node, to_node}`
  """
  def add_edges(graph, edges, opts \\ []) do
    repo = fetch_repo(opts)

    repo.transaction(fn ->
      edges
      |> Enum.map(fn {type, properties, from_node, to_node} ->
        attrs = %{
          graph_id: graph.id,
          type: type,
          properties: properties,
          from_id: from_node.id,
          to_id: to_node.id
        }

        %Edge{}
        |> Edge.changeset(attrs)
        |> repo.insert!()
      end)
    end)
  end

  @doc """
  Delete an edge.
  """
  def delete_edge(%Edge{} = edge, opts \\ []) do
    repo = fetch_repo(opts)

    repo.delete(edge)
  end

  @doc """
  Delete many edges.
  """
  def delete_edges(edges, opts \\ []) do
    repo = fetch_repo(opts)

    ids = Enum.map(edges, fn e -> e.id end)
    repo.delete_all(from(e in Edge, where: e.id in ^ids))
  end

  @doc """
  Update the properties of an edge.
  """
  def update_edge(%Edge{} = edge, %{} = properties, opts \\ []) do
    repo = fetch_repo(opts)

    edge
    |> Edge.changeset(%{properties: properties})
    |> repo.update()
  end

  @doc """
  Fetch the edges connected to the node or nodes

  Additonal Options:
   - `recursive` - continue following the edges until there are no more nodes to explore or the recursion limit is reached
   - `limit` - the maximum number of recursive queries to make
   - `direction` - either :to or :from to select either incoming or outgoing edges

  """
  def edges(nodes, opts \\ []) do
    repo = fetch_repo(opts)
    rec = Keyword.get(opts, :recursive)

    if rec do
      get_edges_rec(repo, nodes, opts)
    else
      get_edges(repo, nodes, opts)
    end
  end

  defp get_edges(repo, %Node{} = node, opts) do
    type = Keyword.get(opts, :type)
    props = Keyword.get(opts, :properties, %{})
    direction = Keyword.get(opts, :direction)

    from(e in Edge)
    |> filter_by_graph_id(node.graph_id)
    |> filter_by_type(type)
    |> filter_by_properties(props)
    |> filter_by_connected_node_ids(direction, [node])
    |> preload_for_direction(direction)
    |> repo.all()
  end

  defp get_edges(repo, [first_node | _] = nodes, opts) do
    type = Keyword.get(opts, :type)
    props = Keyword.get(opts, :properties, %{})
    direction = Keyword.get(opts, :direction)

    from(e in Edge)
    |> filter_by_graph_id(first_node.graph_id)
    |> filter_by_type(type)
    |> filter_by_properties(props)
    |> filter_by_connected_node_ids(direction, nodes)
    |> preload_for_direction(direction)
    |> repo.all()
  end

  defp get_edges_rec(repo, %Node{} = node, opts) do
    get_edges_rec(repo, [node], MapSet.new([node]), opts) |> MapSet.to_list()
  end

  defp get_edges_rec(repo, nodes, opts) do
    get_edges_rec(repo, nodes, MapSet.new(nodes), opts) |> MapSet.to_list()
  end

  defp get_edges_rec(repo, nodes, visited_nodes, opts) do
    type = Keyword.get(opts, :type)
    props = Keyword.get(opts, :properties, %{})
    limit = Keyword.get(opts, :limit, 0)
    direction = Keyword.get(opts, :direction)

    edges =
      MapSet.new(get_edges(repo, nodes, type: type, properties: props, direction: direction))

    connected_nodes =
      case direction do
        :to ->
          MapSet.new(edges, fn e -> e.from end)

        :from ->
          MapSet.new(edges, fn e -> e.to end)

        nil ->
          MapSet.union(MapSet.new(edges, fn e -> e.from end), MapSet.new(edges, fn e -> e.to end))
      end

    # Filter out any seen nodes
    to_follow = MapSet.difference(connected_nodes, visited_nodes)

    if limit > 0 or Enum.empty?(to_follow) do
      edges
    else
      edges
      |> MapSet.union(
        get_edges_rec(
          repo,
          MapSet.to_list(to_follow),
          MapSet.union(MapSet.new(nodes), to_follow),
          type: type,
          limit: limit - 1,
          properties: props,
          direction: direction
        )
      )
    end
  end

  @doc """
  Fetch the edges of a given type coming into a node or list of nodes. Optionally filter by edge properties.

  Additonal Options:
   - `recursive` - continue following the edges until there are no more nodes to explore or the recursion limit is reached
   - `limit` - the maximum number of recursive queries to make
  """
  def incoming_edges(nodes, opts \\ []) do
    edges(nodes, [{:direction, :to} | opts])
  end

  @doc """
  Fetch the edges of a given type coming from a node or list of nodes. Optionally filter by edge properties.

  Additonal Options:
   - `recursive` - continue following the edges until there are no more nodes to explore or the recursion limit is reached
   - `limit` - the maximum number of recursive queries to make
  """
  def outgoing_edges(nodes, opts \\ []) do
    edges(nodes, [{:direction, :from} | opts])
  end

  defp filter_by_graph_id(query, graph_id) do
    from(query, where: ^dynamic([q], q.graph_id == ^graph_id))
  end

  defp filter_by_type(query, nil) do
    query
  end

  defp filter_by_type(query, type) do
    from(query, where: ^dynamic([q], q.type == ^type))
  end

  defp filter_by_properties(query, props) when map_size(props) == 0 do
    query
  end

  defp filter_by_properties(query, props) do
    from(query, where: ^dynamic([q], fragment("? @> ?", q.properties, ^props)))
  end

  defp preload_for_direction(query, direction) do
    case direction do
      :to ->
        preload(query, [:from])

      :from ->
        preload(query, [:to])

      _ ->
        preload(query, [:to, :from])
    end
  end

  defp node_ids(nodes) do
    nodes
    |> MapSet.new(fn n -> n.id end)
    |> MapSet.to_list()
  end

  defp filter_by_connected_node_ids(query, direction, [node]) do
    case direction do
      :to ->
        from(query, where: ^dynamic([e], e.to_id == ^node.id))

      :from ->
        from(query, where: ^dynamic([e], e.from_id == ^node.id))

      nil ->
        from(query, where: ^dynamic([e], e.from_id == ^node.id or e.to_id == ^node.id))

      _ ->
        raise ArgumentError, message: "invalid direction `#{direction}`"
    end
  end

  defp filter_by_connected_node_ids(query, direction, nodes) when is_list(nodes) do
    ids = node_ids(nodes)

    case direction do
      :to ->
        from(query, where: ^dynamic([e], e.to_id in ^ids))

      :from ->
        from(query, where: ^dynamic([e], e.from_id in ^ids))

      nil ->
        from(query, where: ^dynamic([e], e.from_id in ^ids or e.to_id in ^ids))

      _ ->
        raise ArgumentError, message: "invalid direction `#{direction}`"
    end
  end

  defp fetch_repo(opts) do
    repo = Keyword.get(opts, :repo)

    if is_nil(repo) do
      Application.get_env(:edgy, :repo)
    else
      repo
    end
  end
end
