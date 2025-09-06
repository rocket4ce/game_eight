defmodule GameEight.Repo.Migrations.CreateRooms do
  use Ecto.Migration

  def change do
    create table(:rooms, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :type, :string, null: false # "public" or "private"
      add :status, :string, null: false, default: "pending" # "pending", "started", "finished"
      add :access_key, :string # Para partidas privadas
      add :max_players, :integer, null: false, default: 6
      add :min_players, :integer, null: false, default: 2
      add :creator_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :started_at, :utc_datetime
      add :finished_at, :utc_datetime
      add :timeout_minutes, :integer, default: 5 # Tiempo límite para unirse

      timestamps(type: :utc_datetime)
    end

    create index(:rooms, [:creator_id])
    create index(:rooms, [:type])
    create index(:rooms, [:status])
    create index(:rooms, [:access_key])
    create index(:rooms, [:inserted_at])
  end
end
