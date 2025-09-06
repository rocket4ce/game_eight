defmodule GameEight.Repo.Migrations.CreateGameStates do
  use Ecto.Migration

  def change do
    create table(:game_states, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :room_id, references(:rooms, type: :binary_id, on_delete: :delete_all), null: false

      # Game flow control
      add :status, :string, default: "initializing", null: false  # initializing, dice_rolling, playing, finished
      add :current_player_index, :integer, default: 0, null: false
      add :turn_number, :integer, default: 1, null: false
      add :moves_left, :integer, default: 5, null: false
      add :cards_played_this_turn, :integer, default: 0, null: false

      # Game data (JSON fields)
      add :deck, :map, default: %{}, null: false  # Array of remaining cards to draw
      add :table_combinations, :map, default: %{}, null: false  # Object with trio_X, escalera_X keys
      add :dice_results, :map, default: %{}, null: false  # {player_id => dice_value}
      add :turn_order, {:array, :binary_id}, default: [], null: false  # Array of user_ids in turn order

      # Game settings
      add :max_players, :integer, default: 6, null: false
      add :cards_per_player, :integer, default: 8, null: false
      add :timeout_seconds, :integer, default: 300, null: false  # 5 minutes per turn

      # Timestamps
      add :started_at, :utc_datetime
      add :finished_at, :utc_datetime
      add :last_action_at, :utc_datetime, default: fragment("NOW()"), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:game_states, [:room_id])
    create index(:game_states, [:status])
    create index(:game_states, [:current_player_index])
    create index(:game_states, [:last_action_at])
  end
end
