defmodule GameEight.Game.GameState do
  @moduledoc """
  Ecto schema for managing the overall state of a card game.

  This schema stores the central game state including:
  - Current player and turn information
  - Remaining deck and table combinations
  - Game flow control (status, moves left, etc.)
  - Game settings and timestamps
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias GameEight.Game.{Room, PlayerGameState, Card}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "game_states" do
    # Associations
    belongs_to :room, Room
    has_many :player_game_states, PlayerGameState, preload_order: [asc: :player_index]
    has_many :users, through: [:player_game_states, :user]

    # Game flow control
    field :status, :string, default: "initializing"
    field :current_player_index, :integer, default: 0
    field :turn_number, :integer, default: 1
    field :moves_left, :integer, default: 5
    field :cards_played_this_turn, :integer, default: 0

    # Game data (JSON fields)
    field :deck, :map, default: %{}  # Array of Card structs serialized as maps
    field :table_combinations, :map, default: %{}  # {trio_0: [...], escalera_0: [...]}
    field :dice_results, :map, default: %{}  # {user_id => dice_value}
    field :turn_order, {:array, :binary_id}, default: []  # [user_id1, user_id2, ...]

    # Game settings
    field :max_players, :integer, default: 6
    field :cards_per_player, :integer, default: 8
    field :timeout_seconds, :integer, default: 300

    # Timestamps
    field :started_at, :utc_datetime
    field :finished_at, :utc_datetime
    field :last_action_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @statuses ~w(initializing dice_rolling playing finished)

  @doc false
  def changeset(game_state, attrs) do
    game_state
    |> cast(attrs, [
      :room_id, :status, :current_player_index, :turn_number, :moves_left,
      :cards_played_this_turn, :deck, :table_combinations, :dice_results,
      :turn_order, :max_players, :cards_per_player, :timeout_seconds,
      :started_at, :finished_at, :last_action_at
    ])
    |> validate_required([:room_id, :status])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:current_player_index, greater_than_or_equal_to: 0)
    |> validate_number(:turn_number, greater_than: 0)
    |> validate_number(:moves_left, greater_than_or_equal_to: 0, less_than_or_equal_to: 5)
    |> validate_number(:cards_played_this_turn, greater_than_or_equal_to: 0, less_than_or_equal_to: 4)
    |> validate_number(:max_players, greater_than: 1, less_than_or_equal_to: 6)
    |> validate_number(:cards_per_player, greater_than: 0)
    |> validate_number(:timeout_seconds, greater_than: 0)
    |> foreign_key_constraint(:room_id)
    |> unique_constraint(:room_id)
    |> maybe_set_timestamps()
  end

  @doc false
  def status_changeset(game_state, attrs) do
    game_state
    |> cast(attrs, [:status, :started_at, :finished_at, :last_action_at])
    |> validate_inclusion(:status, @statuses)
    |> maybe_set_timestamps()
  end

  @doc false
  def turn_changeset(game_state, attrs) do
    game_state
    |> cast(attrs, [
      :current_player_index, :turn_number, :moves_left,
      :cards_played_this_turn, :last_action_at
    ])
    |> validate_number(:current_player_index, greater_than_or_equal_to: 0)
    |> validate_number(:turn_number, greater_than: 0)
    |> validate_number(:moves_left, greater_than_or_equal_to: 0, less_than_or_equal_to: 5)
    |> validate_number(:cards_played_this_turn, greater_than_or_equal_to: 0, less_than_or_equal_to: 4)
    |> put_change(:last_action_at, DateTime.utc_now(:second))
  end

  @doc false
  def game_data_changeset(game_state, attrs) do
    game_state
    |> cast(attrs, [:deck, :table_combinations, :dice_results, :turn_order, :last_action_at])
    |> put_change(:last_action_at, DateTime.utc_now(:second))
  end

  @doc """
  Gets the current player's user_id based on current_player_index and turn_order.
  """
  def current_player_id(%__MODULE__{current_player_index: index, turn_order: turn_order}) do
    Enum.at(turn_order, index)
  end

  @doc """
  Checks if the game can start (has minimum players and all are ready).
  """
  def can_start?(%__MODULE__{status: "initializing", player_game_states: players}) do
    length(players) >= 2 && Enum.all?(players, & &1.is_ready)
  end
  def can_start?(_), do: false

  @doc """
  Checks if the game is finished (a player has no cards left).
  """
  def is_finished?(%__MODULE__{player_game_states: players}) do
    Enum.any?(players, fn player ->
      hand_cards = Map.get(player.hand_cards, "cards", [])
      length(hand_cards) == 0
    end)
  end

  @doc """
  Converts the deck field (array of maps) to Card structs.
  """
  def deck_to_cards(%__MODULE__{deck: %{"cards" => cards}}) when is_list(cards) do
    Enum.map(cards, &map_to_card/1)
  end
  def deck_to_cards(_), do: []

  @doc """
  Converts Card structs to the deck field format.
  """
  def cards_to_deck(cards) when is_list(cards) do
    %{"cards" => Enum.map(cards, &card_to_map/1)}
  end

  @doc """
  Gets table combinations as Card structs.
  Automatically reorders sequences for proper display.
  """
  def table_combinations_to_cards(%__MODULE__{table_combinations: combinations}) do
    alias GameEight.Game.Card

    combinations
    |> Enum.map(fn {key, cards} ->
      card_structs = Enum.map(cards, &map_to_card/1)

      # Apply automatic reordering for sequences when loading from database
      reordered_cards = if String.starts_with?(key, "sequence") do
        Card.reorder_sequence(card_structs)
      else
        card_structs
      end

      {key, reordered_cards}
    end)
    |> Enum.into(%{})
  end

  # Private helper functions

  defp maybe_set_timestamps(changeset) do
    status = get_change(changeset, :status)
    now = DateTime.utc_now(:second)

    case status do
      "playing" -> put_change(changeset, :started_at, now)
      "finished" -> put_change(changeset, :finished_at, now)
      _ -> changeset
    end
    |> put_change(:last_action_at, now)
  end

  # Convert between Card structs and maps for JSON serialization
  defp card_to_map(%Card{} = card) do
    Map.from_struct(card)
  end

  defp map_to_card(%{} = map) do
    # Handle both string and atom keys from JSON
    card_map = %{
      position: map["position"] || map[:position],
      card: map["card"] || map[:card],
      type: atomize_suit(map["type"] || map[:type]),
      deck: atomize_deck(map["deck"] || map[:deck])
    }

    struct(Card, card_map)
  end

  defp atomize_suit(suit) when is_binary(suit) do
    case suit do
      "spades" -> :spades
      "hearts" -> :hearts
      "diamonds" -> :diamonds
      "clubs" -> :clubs
      _ -> :spades # default fallback
    end
  end
  defp atomize_suit(suit) when is_atom(suit), do: suit
  defp atomize_suit(_), do: :spades

  defp atomize_deck(deck) when is_binary(deck) do
    case deck do
      "red" -> :red
      "blue" -> :blue
      _ -> :red # default fallback
    end
  end
  defp atomize_deck(deck) when is_atom(deck), do: deck
  defp atomize_deck(_), do: :red
end
