defmodule GameEight.Game.PlayerGameState do
  @moduledoc """
  Ecto schema for managing individual player state within a card game.

  This schema stores each player's specific game data:
  - Hand cards and player position
  - Player status (off/on) and readiness
  - Statistics and last actions
  - Dice roll results for turn order
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias GameEight.Game.{GameState, Card}
  alias GameEight.Accounts.User
  alias GameEight.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "player_game_states" do
    # Associations
    belongs_to :game_state, GameState
    belongs_to :user, User

    # Player position and status
    # 0, 1, 2, etc. for turn order
    field :player_index, :integer
    # player_off, player_on
    field :player_status, :string, default: "player_off"

    # Player cards and game data
    # %{"cards" => [Card maps]}
    field :hand_cards, :map, default: %{}
    # Dice result for turn order determination
    field :dice_roll, :integer

    # Player statistics
    field :cards_played_total, :integer, default: 0
    field :combinations_made, :integer, default: 0
    field :moves_made_this_turn, :integer, default: 0

    # Player actions and state
    # "play_cards", "draw_card", "pass_turn", etc.
    field :last_action, :string
    field :last_action_at, :utc_datetime
    field :is_ready, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @player_statuses ~w(player_off player_on)
  @actions ~w(play_cards draw_card pass_turn make_combination add_to_combination)

  @doc false
  def changeset(player_game_state, attrs) do
    player_game_state
    |> cast(attrs, [
      :game_state_id,
      :user_id,
      :player_index,
      :player_status,
      :hand_cards,
      :dice_roll,
      :cards_played_total,
      :combinations_made,
      :moves_made_this_turn,
      :last_action,
      :last_action_at,
      :is_ready
    ])
    |> validate_required([:game_state_id, :user_id, :player_index])
    |> validate_inclusion(:player_status, @player_statuses)
    |> validate_inclusion(:last_action, @actions, allow_nil: true)
    |> validate_number(:player_index, greater_than_or_equal_to: 0)
    |> validate_number(:dice_roll,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 6,
      allow_nil: true
    )
    |> validate_number(:cards_played_total, greater_than_or_equal_to: 0)
    |> validate_number(:combinations_made, greater_than_or_equal_to: 0)
    |> validate_number(:moves_made_this_turn,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 5
    )
    |> foreign_key_constraint(:game_state_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:game_state_id, :user_id])
    |> unique_constraint([:game_state_id, :player_index])
  end

  @doc false
  def action_changeset(player_game_state, attrs) do
    player_game_state
    |> cast(attrs, [:last_action, :last_action_at, :moves_made_this_turn, :cards_played_total])
    |> validate_inclusion(:last_action, @actions, allow_nil: true)
    |> validate_number(:moves_made_this_turn,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 5
    )
    |> validate_number(:cards_played_total, greater_than_or_equal_to: 0)
    |> put_change(:last_action_at, DateTime.utc_now(:second))
  end

  @doc false
  def hand_changeset(player_game_state, attrs) do
    player_game_state
    |> cast(attrs, [:hand_cards])
    |> validate_hand_cards()
  end

  @doc false
  def status_changeset(player_game_state, attrs) do
    player_game_state
    |> cast(attrs, [:player_status, :is_ready])
    |> validate_inclusion(:player_status, @player_statuses)
  end

  @doc false
  def dice_changeset(player_game_state, attrs) do
    player_game_state
    |> cast(attrs, [:dice_roll])
    |> validate_number(:dice_roll, greater_than_or_equal_to: 1, less_than_or_equal_to: 6)
  end

  @doc """
  Gets the player's hand cards as Card structs.
  """
  def hand_to_cards(%__MODULE__{hand_cards: %{"cards" => cards}}) when is_list(cards) do
    Enum.map(cards, &map_to_card/1)
  end

  def hand_to_cards(_), do: []

  @doc """
  Converts Card structs to the hand_cards field format.
  """
  def cards_to_hand(cards) when is_list(cards) do
    %{"cards" => Enum.map(cards, &card_to_map/1)}
  end

  @doc """
  Checks if the player can play cards (is their turn and has moves left).
  """
  def can_play?(%__MODULE__{} = player, %GameState{} = game_state) do
    is_current_player = GameState.current_player_id(game_state) == player.user_id
    has_moves = game_state.moves_left > 0
    game_active = game_state.status == "playing"

    is_current_player && has_moves && game_active
  end

  @doc """
  Checks if the player needs to draw a card (no valid plays available).
  """
  def needs_to_draw?(%__MODULE__{} = player, %GameState{} = game_state) do
    # This would need game logic to determine if player has valid moves
    # For now, simplified check
    can_play?(player, game_state) && game_state.moves_left == 5
  end

  @doc """
  Checks if the player has won (no cards left in hand).
  """
  def has_won?(%__MODULE__{hand_cards: %{"cards" => cards}}) when is_list(cards) do
    length(cards) == 0
  end

  def has_won?(_), do: false

  @doc """
  Gets the number of cards in the player's hand.
  """
  def hand_size(%__MODULE__{hand_cards: %{"cards" => cards}}) when is_list(cards) do
    length(cards)
  end

  def hand_size(_), do: 0

  @doc """
  Removes specified cards from the player's hand.
  """
  def remove_cards_from_hand(%__MODULE__{} = player_state, cards_to_remove) do
    current_hand = hand_to_cards(player_state)
    cards_to_remove_ids = Enum.map(cards_to_remove, &Card.dom_id/1)

    remaining_cards =
      current_hand
      |> Enum.reject(fn card -> Card.dom_id(card) in cards_to_remove_ids end)
      |> Card.resequence_positions()

    player_state
    |> hand_changeset(%{hand_cards: cards_to_hand(remaining_cards)})
    |> Repo.update()
  end

  @doc """
  Adds cards to the player's hand.
  """
  def add_cards_to_hand(%__MODULE__{} = player_state, new_cards) do
    current_hand = hand_to_cards(player_state)

    updated_hand =
      (current_hand ++ new_cards)
      |> Card.resequence_positions()

    player_state
    |> hand_changeset(%{hand_cards: cards_to_hand(updated_hand)})
    |> Repo.update()
  end

  @doc """
  Activates a player (changes status from player_off to player_on).
  """
  def activate_player(%__MODULE__{player_status: "player_off"} = player_state) do
    player_state
    |> status_changeset(%{player_status: "player_on"})
    |> Repo.update()
  end

  def activate_player(%__MODULE__{} = player_state), do: {:ok, player_state}

  # Private helper functions

  defp validate_hand_cards(changeset) do
    case get_field(changeset, :hand_cards) do
      %{"cards" => cards} when is_list(cards) ->
        # Validate that cards are properly structured
        if Enum.all?(cards, &valid_card_map?/1) do
          changeset
        else
          add_error(changeset, :hand_cards, "contains invalid card data")
        end

      _ ->
        add_error(changeset, :hand_cards, "must be a map with 'cards' key containing an array")
    end
  end

  defp valid_card_map?(card_map) when is_map(card_map) do
    # Check if we have the required fields (either as strings or atoms)
    position = get_value(card_map, "position", :position)
    card = get_value(card_map, "card", :card)
    type = get_value(card_map, "type", :type)
    deck = get_value(card_map, "deck", :deck)

    is_integer(position) and is_binary(card) and not is_nil(type) and not is_nil(deck)
  end

  defp valid_card_map?(_), do: false

  # Convert between Card structs and maps for JSON serialization
  defp card_to_map(%Card{} = card) do
    %{
      "position" => card.position,
      "card" => card.card,
      "type" => card.type,
      "deck" => card.deck
    }
  end

  defp map_to_card(%{} = map) do
    # Handle both string and atom keys from JSON
    card_map = %{
      position: get_value(map, "position", :position),
      card: get_value(map, "card", :card),
      type: atomize_suit(get_value(map, "type", :type)),
      deck: atomize_deck(get_value(map, "deck", :deck))
    }

    struct(Card, card_map)
  end

  defp get_value(map, string_key, atom_key) do
    map[string_key] || map[atom_key]
  end

  defp atomize_suit(suit) when is_binary(suit) do
    case suit do
      "spades" -> :spades
      "hearts" -> :hearts
      "diamonds" -> :diamonds
      "clubs" -> :clubs
      # default fallback
      _ -> :spades
    end
  end

  defp atomize_suit(suit) when is_atom(suit), do: suit
  defp atomize_suit(_), do: :spades

  defp atomize_deck(deck) when is_binary(deck) do
    case deck do
      "red" -> :red
      "blue" -> :blue
      # default fallback
      _ -> :red
    end
  end

  defp atomize_deck(deck) when is_atom(deck), do: deck
  defp atomize_deck(_), do: :red
end
