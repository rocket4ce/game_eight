defmodule GameEight.Game.Card do
  @moduledoc """
  Card structure and deck management for the GameEight card game.

  This module handles a two-deck system (red and blue English decks)
  for a total of 104 cards. Each card has a position, value, suit, and deck color.
  Designed for modern graphical UI with drag & drop functionality.
  """

  @derive Jason.Encoder
  defstruct [:position, :card, :type, :deck]

  @type t :: %__MODULE__{
    position: non_neg_integer(),
    card: String.t(),
    type: atom(),
    deck: atom()
  }

  # Card values in order for sequence validation
  @card_values ~w(Ace 2 3 4 5 6 7 8 9 10 Jack Queen King)
  @suits [:spades, :hearts, :diamonds, :clubs]

  @doc """
  Creates a complete deck of 104 cards (2 English decks: red and blue).

  ## Examples

      iex> cards = GameEight.Game.Card.create_full_deck()
      iex> length(cards)
      104
      iex> Enum.count(cards, &(&1.deck == :red))
      52
  """
  def create_full_deck do
    red_deck = create_single_deck(:red, 0)
    blue_deck = create_single_deck(:blue, 52)

    red_deck ++ blue_deck
  end

  @doc """
  Creates a single deck of 52 cards for the specified color and starting position.
  """
  def create_single_deck(deck_color, start_position) do
    for {suit, suit_index} <- Enum.with_index(@suits),
        {card, card_index} <- Enum.with_index(@card_values) do
      %__MODULE__{
        position: start_position + (suit_index * 13) + card_index,
        card: card,
        type: suit,
        deck: deck_color
      }
    end
  end

  @doc """
  Shuffles a deck of cards using cryptographically secure randomness.

  ## Examples

      iex> deck = GameEight.Game.Card.create_full_deck()
      iex> shuffled = GameEight.Game.Card.shuffle(deck)
      iex> length(shuffled) == 104
      true
  """
  def shuffle(cards) when is_list(cards) do
    Enum.shuffle(cards)
  end

  @doc """
  Deals cards to players from the deck.

  ## Parameters
  - deck: List of cards to deal from
  - num_players: Number of players (2-6)
  - cards_per_player: Number of cards per player (default: 8)

  ## Returns
  - {player_hands, remaining_deck} where player_hands is a list of hands

  ## Examples

      iex> deck = GameEight.Game.Card.create_full_deck() |> GameEight.Game.Card.shuffle()
      iex> {hands, remaining} = GameEight.Game.Card.deal_cards(deck, 3, 8)
      iex> length(hands) == 3
      true
      iex> Enum.all?(hands, &(length(&1) == 8))
      true
      iex> length(remaining) == 80
      true
  """
  def deal_cards(deck, num_players, cards_per_player \\ 8)
      when is_list(deck) and is_integer(num_players) and is_integer(cards_per_player) do
    total_cards_needed = num_players * cards_per_player

    if length(deck) < total_cards_needed do
      {:error, :insufficient_cards}
    else
      {cards_to_deal, remaining_deck} = Enum.split(deck, total_cards_needed)

      hands =
        cards_to_deal
        |> Enum.with_index()
        |> Enum.group_by(fn {_card, index} -> rem(index, num_players) end, fn {card, _index} -> card end)
        |> Map.values()

      {hands, remaining_deck}
    end
  end

  @doc """
  Repositions cards with sequential positions starting from 0.
  """
  def reposition_cards(cards) when is_list(cards) do
    Enum.with_index(cards, fn card, index ->
      %{card | position: index}
    end)
  end

  @doc """
  Gets the numeric value of a card for comparison purposes.
  Ace = 1, Jack = 11, Queen = 12, King = 13
  """
  def card_value(%__MODULE__{card: card}) do
    case card do
      "Ace" -> 1
      "Jack" -> 11
      "Queen" -> 12
      "King" -> 13
      number_str -> String.to_integer(number_str)
    end
  end

  @doc """
  Checks if cards form a valid sequence (4+ consecutive cards of same suit).
  """
  def valid_sequence?(cards) when length(cards) < 4, do: false

  def valid_sequence?(cards) when is_list(cards) do
    # All cards must be same suit
    suits = Enum.map(cards, & &1.type) |> Enum.uniq()

    if length(suits) == 1 do
      # Sort by value and check consecutive
      values =
        cards
        |> Enum.map(&card_value/1)
        |> Enum.sort()

      consecutive?(values)
    else
      false
    end
  end

  @doc """
  Checks if cards form a valid trio (3+ cards of same value, different suits).
  """
  def valid_trio?(cards) when length(cards) < 3, do: false

  def valid_trio?(cards) when is_list(cards) do
    # All cards must be same value
    values = Enum.map(cards, & &1.card) |> Enum.uniq()

    if length(values) == 1 do
      # All cards must have different suits (but can be same deck color)
      suits = Enum.map(cards, & &1.type) |> Enum.uniq()
      length(suits) == length(cards)
    else
      false
    end
  end

  # ===============================
  # GRAPHICAL UI FUNCTIONS
  # ===============================

  @doc """
  Returns a short display name for the card (for UI).
  """
  def display_name(%__MODULE__{card: card}) do
    case card do
      "Ace" -> "A"
      "Jack" -> "J"
      "Queen" -> "Q"
      "King" -> "K"
      number -> number
    end
  end

  @doc """
  Gets the suit symbol for UI display.
  """
  def suit_symbol(suit) do
    case suit do
      :spades -> "♠"
      :hearts -> "♥"
      :diamonds -> "♦"
      :clubs -> "♣"
    end
  end

  @doc """
  Returns CSS classes for styling a card based on its properties.
  """
  def css_classes(%__MODULE__{type: type, deck: deck, card: card}) do
    suit_color = case type do
      :spades -> "text-gray-800"
      :clubs -> "text-gray-800"
      :hearts -> "text-red-600"
      :diamonds -> "text-red-600"
    end

    deck_bg = case deck do
      :red -> "bg-red-50 border-red-200"
      :blue -> "bg-blue-50 border-blue-200"
    end

    card_type = case card do
      face when face in ["Jack", "Queen", "King"] -> "face-card"
      "Ace" -> "ace-card"
      _ -> "number-card"
    end

    "card draggable #{suit_color} #{deck_bg} #{card_type}"
  end

  @doc """
  Gets the deck color for UI styling.
  """
  def deck_color(deck) do
    case deck do
      :red -> "#DC2626"
      :blue -> "#2563EB"
    end
  end

  @doc """
  Gets the suit color for styling (different from deck color).
  Red suits: hearts, diamonds
  Black suits: spades, clubs
  """
  def suit_color(suit) do
    case suit do
      suit when suit in [:hearts, :diamonds] -> "#DC2626"
      suit when suit in [:spades, :clubs] -> "#1F2937"
    end
  end

  @doc """
  Generates a unique ID for the card element in the DOM.
  Used for drag & drop functionality.
  """
  def dom_id(%__MODULE__{position: pos, card: card, type: type, deck: deck}) do
    "card-#{pos}-#{String.downcase(card)}-#{type}-#{deck}"
  end

  @doc """
  Creates data attributes for drag & drop functionality.
  Returns a map of HTML data attributes.
  """
  def drag_data(%__MODULE__{} = card) do
    %{
      "data-card-id" => dom_id(card),
      "data-card-value" => card.card,
      "data-card-suit" => card.type,
      "data-card-deck" => card.deck,
      "data-card-position" => card.position,
      "draggable" => "true"
    }
  end

  @doc """
  Resequences positions of cards after removal/rearrangement.
  Maintains order while updating positions for DOM consistency.
  """
  def resequence_positions(cards) do
    cards
    |> Enum.with_index()
    |> Enum.map(fn {card, new_position} ->
      %{card | position: new_position}
    end)
  end

  # ===============================
  # PRIVATE HELPER FUNCTIONS
  # ===============================

  # Checks if a list of numbers is consecutive
  defp consecutive?([]), do: false
  defp consecutive?([_single]), do: false
  defp consecutive?(values) do
    values
    |> Enum.with_index()
    |> Enum.all?(fn {value, index} ->
      index == 0 || value == Enum.at(values, index - 1) + 1
    end)
  end
end
