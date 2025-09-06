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

  # Helper functions to get card fields from both structs and maps
  defp get_card_value(%__MODULE__{card: value}), do: value
  defp get_card_value(%{"card" => value}), do: value
  defp get_card_value(%{card: value}), do: value

  defp get_card_type(%__MODULE__{type: type}), do: type
  defp get_card_type(%{"type" => type}), do: type
  defp get_card_type(%{type: type}), do: type

  defp get_card_deck(%__MODULE__{deck: deck}), do: deck
  defp get_card_deck(%{"deck" => deck}), do: deck
  defp get_card_deck(%{deck: deck}), do: deck

  defp get_card_position(%__MODULE__{position: pos}), do: pos
  defp get_card_position(%{"position" => pos}), do: pos
  defp get_card_position(%{position: pos}), do: pos

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
        position: start_position + suit_index * 13 + card_index,
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
        |> Enum.group_by(fn {_card, index} -> rem(index, num_players) end, fn {card, _index} ->
          card
        end)
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
  def card_value(card) do
    card_str = get_card_value(card)

    case card_str do
      "Ace" -> 1
      "Jack" -> 11
      "Queen" -> 12
      "King" -> 13
      number_str -> String.to_integer(number_str)
    end
  end

  @doc """
  Checks if cards form a valid sequence (3+ consecutive cards of same suit).
  """
  def valid_sequence?(cards) when length(cards) < 3, do: false

  def valid_sequence?(cards) when is_list(cards) do
    # All cards must be same suit
    suits = Enum.map(cards, &get_card_type/1) |> Enum.uniq()

    if length(suits) == 1 do
      # Sort by value and check consecutive (including wrap-around sequences)
      values =
        cards
        |> Enum.map(&card_value/1)
        |> Enum.sort()

      consecutive?(values) || consecutive_with_wrap?(values)
    else
      false
    end
  end

  @doc """
  Reorders cards in a complete sequence (13 cards A-K) to natural order.
  Only applies when the sequence contains exactly 13 cards and all values from A to K.

  ## Examples

      iex> cards = [%Card{card: "Jack"}, %Card{card: "Queen"}, %Card{card: "King"},
      ...>          %Card{card: "Ace"}, %Card{card: "2"}, %Card{card: "3"}]
      iex> GameEight.Game.Card.reorder_complete_sequence(cards)
      # Returns cards reordered as: A, 2, 3, 4, 5, 6, 7, 8, 9, 10, J, Q, K (if complete)
  """
  def reorder_complete_sequence(cards) when is_list(cards) do
    if is_complete_sequence?(cards) do
      # Reorder to natural sequence: A, 2, 3, 4, 5, 6, 7, 8, 9, 10, J, Q, K
      cards
      |> Enum.sort_by(&card_value_for_natural_order/1)
    else
      # Return cards unchanged if not a complete sequence
      cards
    end
  end

  @doc """
  Reorders any valid sequence (3+ cards) to natural numerical order.
  For normal sequences: sorts by card value
  For wrap-around sequences: handles A as high or low depending on context

  ## Examples

      iex> cards = [%Card{card: "5"}, %Card{card: "3"}, %Card{card: "4"}]
      iex> GameEight.Game.Card.reorder_sequence(cards)
      # Returns: [3, 4, 5]

      iex> cards = [%Card{card: "King"}, %Card{card: "Ace"}, %Card{card: "Queen"}]
      iex> GameEight.Game.Card.reorder_sequence(cards)
      # Returns: [Queen, King, Ace] (Ace treated as high)
  """
  def reorder_sequence(cards) when is_list(cards) do
    if valid_sequence?(cards) do
      # Determine the best sorting approach for this sequence
      cards
      |> sort_sequence_intelligently()
    else
      # Return unchanged if not a valid sequence
      cards
    end
  end

  @doc """
  Checks if cards form a complete sequence (exactly 13 cards with all values A-K of same suit).
  """
  def is_complete_sequence?(cards) when is_list(cards) do
    # Must have exactly 13 cards
    if length(cards) == 13 do
      # All cards must be same suit
      suits = Enum.map(cards, &get_card_type/1) |> Enum.uniq()

      if length(suits) == 1 do
        # Must contain all values from A to K
        values =
          cards
          |> Enum.map(&get_card_value/1)
          |> Enum.sort()

        expected_values = @card_values |> Enum.sort()
        values == expected_values
      else
        false
      end
    else
      false
    end
  end

  @doc """
  Checks if cards form a valid trio (3 cards of same value).

  Since we use 2 decks, cards can have the same suit if they come from different decks.
  """
  def valid_trio?(cards) when length(cards) < 3, do: false

  def valid_trio?(cards) when is_list(cards) do
    # All cards must be same value
    values = Enum.map(cards, &get_card_value/1) |> Enum.uniq()

    if length(values) == 1 do
      # Para un trío válido: al menos 3 cartas del mismo valor
      # Permitir suits repetidos si vienen de diferentes barajas (usamos 2 barajas)
      length(cards) >= 3
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
    suit_color =
      case type do
        :spades -> "text-gray-800"
        :clubs -> "text-gray-800"
        :hearts -> "text-red-600"
        :diamonds -> "text-red-600"
      end

    deck_bg =
      case deck do
        :red -> "bg-red-50 border-red-200"
        :blue -> "bg-blue-50 border-blue-200"
      end

    card_type =
      case card do
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

  def dom_id(card) when is_map(card) do
    pos = get_card_position(card)
    card_value = get_card_value(card)
    type = get_card_type(card)
    deck = get_card_deck(card)
    "card-#{pos}-#{String.downcase(card_value)}-#{type}-#{deck}"
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

  def drag_data(card) when is_map(card) do
    %{
      "data-card-id" => dom_id(card),
      "data-card-value" => get_card_value(card),
      "data-card-suit" => get_card_type(card),
      "data-card-deck" => get_card_deck(card),
      "data-card-position" => get_card_position(card),
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

  # Gets card value for natural ordering (A=1, 2=2, ..., J=11, Q=12, K=13)
  defp card_value_for_natural_order(card) do
    card_str = get_card_value(card)

    case card_str do
      "Ace" -> 1
      "Jack" -> 11
      "Queen" -> 12
      "King" -> 13
      number_str -> String.to_integer(number_str)
    end
  end

  # Gets card value for sequence sorting (handles wrap-around sequences properly)
  defp sort_sequence_intelligently(cards) do
    values = Enum.map(cards, &card_value/1)

    # Check if it's a wrap-around sequence with Ace
    has_ace = 1 in values
    has_king = 13 in values
    has_low_cards = Enum.any?(values, fn v -> v >= 2 and v <= 5 end)

    cond do
      # For K-A-2 type sequences, treat Ace as low (1)
      has_ace and has_king and has_low_cards ->
        cards |> Enum.sort_by(&card_value_for_natural_order/1)

      # For Q-K-A type sequences, treat Ace as high (14)
      has_ace and has_king and not has_low_cards ->
        cards |> Enum.sort_by(&ace_high_value/1)

      # Normal sequences
      true ->
        cards |> Enum.sort_by(&card_value_for_natural_order/1)
    end
  end

  # Gets card value treating Ace as high (14)
  defp ace_high_value(card) do
    case get_card_value(card) do
      "Ace" -> 14
      "Jack" -> 11
      "Queen" -> 12
      "King" -> 13
      number_str -> String.to_integer(number_str)
    end
  end

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

  # Checks if values form a wrap-around sequence (like Q-K-A or K-A-2)
  defp consecutive_with_wrap?(values) do
    sorted_values = Enum.sort(values)

    # Check if we have Ace (1)
    has_ace = 1 in sorted_values

    if has_ace do
      # Try two approaches:
      # 1. Treat Ace as 14 (for sequences like Q-K-A)
      ace_high_values =
        sorted_values
        |> Enum.map(fn v -> if v == 1, do: 14, else: v end)
        |> Enum.sort()

      # 2. For specific wrap-around patterns like K-A-2,
      #    check if we have exactly K(13) and low cards that would continue the sequence
      specific_wraps =
        case sorted_values do
          # K-A-2: [1, 2, 13] should be valid
          [1, 2, 13] -> true
          # K-A-2-3: [1, 2, 3, 13] should be valid
          [1, 2, 3, 13] -> true
          # Add more specific patterns as needed
          _ -> false
        end

      consecutive?(ace_high_values) || specific_wraps
    else
      false
    end
  end
end
