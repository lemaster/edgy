defmodule Edgy.Edge do
  use Ecto.Schema
  import Ecto.Changeset

  alias Edgy.Graph
  alias Edgy.Node

  schema "edgy_edges" do
    field(:type, :string)
    field(:properties, :map)
    belongs_to(:graph, Graph)
    belongs_to(:to, Node)
    belongs_to(:from, Node)

    timestamps(type: :utc_datetime)
  end

  def changeset(edge, attrs) do
    edge
    |> cast(attrs, [:type, :properties, :graph_id, :to_id, :from_id])
    |> validate_required([:type, :properties, :graph_id, :to_id, :from_id])
  end
end
