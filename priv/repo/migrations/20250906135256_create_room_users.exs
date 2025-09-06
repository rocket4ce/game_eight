defmodule GameEight.Repo.Migrations.CreateRoomUsers do
  use Ecto.Migration

  def change do
    create table(:room_users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :room_id, references(:rooms, on_delete: :delete_all, type: :binary_id), null: false
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      # Posición del jugador en la mesa (0-5)
      add :position, :integer, null: false
      add :joined_at, :utc_datetime, null: false
      # "active", "disconnected", "left"
      add :status, :string, default: "active"

      timestamps(type: :utc_datetime)
    end

    create index(:room_users, [:room_id])
    create index(:room_users, [:user_id])
    create unique_index(:room_users, [:room_id, :user_id])
    create unique_index(:room_users, [:room_id, :position])
  end
end
