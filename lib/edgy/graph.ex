defmodule Edgy.Graph do
  use Ecto.Schema
  import Ecto.Changeset

  alias Edgy.Edge
  alias Edgy.Node

  schema "edgy_graphs" do
    field(:name, :string)
    has_many(:edges, Edge)
    has_many(:nodes, Node)
    timestamps(type: :utc_datetime)
  end

  def changeset(graph, attrs) do
    graph
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
