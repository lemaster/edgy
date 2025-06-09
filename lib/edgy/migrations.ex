defmodule Edgy.Migrations do
  use Ecto.Migration

  def run_migrations do
    setup_tables()
  end

  defp setup_tables do
    create table(:edgy_graphs) do
      add(:name, :text, null: false)
      timestamps(type: :utc_datetime)
    end

    create(unique_index(:edgy_graphs, [:name]))

    create table(:edgy_nodes) do
      add(:type, :text, null: false)
      add(:properties, :map, null: false, default: %{})
      add(:graph_id, references(:edgy_graphs, on_delete: :delete_all), null: false)
      timestamps(type: :utc_datetime)
    end

    create(index(:edgy_nodes, [:graph_id]))
    create(index(:edgy_nodes, [:type]))

    create table(:edgy_edges) do
      add(:graph_id, references(:edgy_graphs, on_delete: :delete_all), null: false)
      add(:type, :text, null: false)
      add(:properties, :map, null: false, default: %{})
      add(:to_id, references(:edgy_nodes, on_delete: :delete_all), null: false)
      add(:from_id, references(:edgy_nodes, on_delete: :delete_all), null: false)
      timestamps(type: :utc_datetime)
    end

    create(index(:edgy_edges, [:graph_id]))
    create(index(:edgy_edges, [:type]))
    create(index(:edgy_edges, [:to_id]))
    create(index(:edgy_edges, [:from_id]))
  end
end
