defmodule GameEight.Repo.Migrations.CreatePlayerGameStates do
  use Ecto.Migration

  def change do
    create table(:player_game_states, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :game_state_id, references(:game_states, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      # Player position and status
      add :player_index, :integer, null: false  # 0, 1, 2, etc. for turn order
      add :player_status, :string, default: "player_off", null: false  # player_off, player_on

      # Player cards and game data
      add :hand_cards, :map, default: %{}, null: false  # Array of card objects
      add :dice_roll, :integer  # Dice result for turn order determination

      # Player statistics
      add :cards_played_total, :integer, default: 0, null: false
      add :combinations_made, :integer, default: 0, null: false
      add :moves_made_this_turn, :integer, default: 0, null: false

      # Player actions and state
      add :last_action, :string  # "play_cards", "draw_card", "pass_turn", etc.
      add :last_action_at, :utc_datetime
      add :is_ready, :boolean, default: false, null: false  # Ready for next phase

      timestamps(type: :utc_datetime)
    end

    create unique_index(:player_game_states, [:game_state_id, :user_id])
    create unique_index(:player_game_states, [:game_state_id, :player_index])
    create index(:player_game_states, [:user_id])
    create index(:player_game_states, [:player_status])
    create index(:player_game_states, [:is_ready])
  end
end
