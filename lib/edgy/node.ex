defmodule Edgy.Node do
  use Ecto.Schema
  import Ecto.Changeset

  alias Edgy.Graph

  schema "edgy_nodes" do
    field(:type, :string)
    field(:properties, :map)
    belongs_to(:graph, Graph)

    timestamps(type: :utc_datetime)
  end

  def changeset(node, attrs) do
    node
    |> cast(attrs, [:type, :properties, :graph_id])
    |> validate_required([:type, :properties, :graph_id])
  end
end
