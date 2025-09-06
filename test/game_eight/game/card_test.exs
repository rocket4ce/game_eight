defmodule GameEight.Game.CardTest do
  use ExUnit.Case, async: true

  alias GameEight.Game.Card

  describe "create_full_deck/0" do
    test "creates 104 cards (2 decks of 52)" do
      deck = Card.create_full_deck()
      assert length(deck) == 104
    end

    test "creates equal number of red and blue cards" do
      deck = Card.create_full_deck()
      red_cards = Enum.count(deck, &(&1.deck == :red))
      blue_cards = Enum.count(deck, &(&1.deck == :blue))

      assert red_cards == 52
      assert blue_cards == 52
    end

    test "creates 4 suits with 13 cards each per deck" do
      deck = Card.create_full_deck()

      for deck_color <- [:red, :blue] do
        deck_cards = Enum.filter(deck, &(&1.deck == deck_color))

        for suit <- [:spades, :hearts, :diamonds, :clubs] do
          suit_cards = Enum.filter(deck_cards, &(&1.type == suit))
          assert length(suit_cards) == 13
        end
      end
    end
  end

  describe "shuffle/1" do
    test "returns same number of cards" do
      deck = Card.create_full_deck()
      shuffled = Card.shuffle(deck)

      assert length(shuffled) == length(deck)
    end

    test "contains the same cards" do
      deck = Card.create_full_deck()
      shuffled = Card.shuffle(deck)

      # Sort both decks by a consistent key to compare
      sort_fn = fn card -> {card.deck, card.type, card.card} end
      sorted_original = Enum.sort_by(deck, sort_fn)
      sorted_shuffled = Enum.sort_by(shuffled, sort_fn)

      assert sorted_original == sorted_shuffled
    end
  end

  describe "deal_cards/3" do
    test "deals correct number of cards to each player" do
      deck = Card.create_full_deck() |> Card.shuffle()
      {hands, remaining} = Card.deal_cards(deck, 3, 8)

      assert length(hands) == 3
      assert Enum.all?(hands, &(length(&1) == 8))
      assert length(remaining) == 104 - 3 * 8
    end

    test "returns error when insufficient cards" do
      deck = Card.create_full_deck()
      result = Card.deal_cards(deck, 15, 8)

      assert result == {:error, :insufficient_cards}
    end

    test "each player gets different cards" do
      deck = Card.create_full_deck() |> Card.shuffle()
      {hands, _remaining} = Card.deal_cards(deck, 2, 8)

      [hand1, hand2] = hands

      # No card should appear in both hands
      hand1_cards = Enum.map(hand1, &"#{&1.card}-#{&1.type}-#{&1.deck}")
      hand2_cards = Enum.map(hand2, &"#{&1.card}-#{&1.type}-#{&1.deck}")

      assert MapSet.disjoint?(MapSet.new(hand1_cards), MapSet.new(hand2_cards))
    end
  end

  describe "valid_trio?/1" do
    test "returns true for valid trio" do
      cards = [
        %Card{card: "King", type: :spades, deck: :red, position: 0},
        %Card{card: "King", type: :hearts, deck: :blue, position: 1},
        %Card{card: "King", type: :diamonds, deck: :red, position: 2}
      ]

      assert Card.valid_trio?(cards)
    end

    test "returns false for cards with different values" do
      cards = [
        %Card{card: "King", type: :spades, deck: :red, position: 0},
        %Card{card: "Queen", type: :hearts, deck: :blue, position: 1},
        %Card{card: "King", type: :diamonds, deck: :red, position: 2}
      ]

      refute Card.valid_trio?(cards)
    end

    test "returns false for less than 3 cards" do
      cards = [
        %Card{card: "King", type: :spades, deck: :red, position: 0},
        %Card{card: "King", type: :hearts, deck: :blue, position: 1}
      ]

      refute Card.valid_trio?(cards)
    end

    test "returns true for cards with same suit from different decks" do
      cards = [
        %Card{card: "King", type: :spades, deck: :red, position: 0},
        %Card{card: "King", type: :spades, deck: :blue, position: 1},
        %Card{card: "King", type: :diamonds, deck: :red, position: 2}
      ]

      assert Card.valid_trio?(cards)
    end
  end

  describe "valid_sequence?/1" do
    test "returns true for valid sequence" do
      cards = [
        %Card{card: "Ace", type: :hearts, deck: :red, position: 0},
        %Card{card: "2", type: :hearts, deck: :blue, position: 1},
        %Card{card: "3", type: :hearts, deck: :red, position: 2},
        %Card{card: "4", type: :hearts, deck: :blue, position: 3}
      ]

      assert Card.valid_sequence?(cards)
    end

    test "returns false for cards with different suits" do
      cards = [
        %Card{card: "Ace", type: :hearts, deck: :red, position: 0},
        %Card{card: "2", type: :spades, deck: :blue, position: 1},
        %Card{card: "3", type: :hearts, deck: :red, position: 2},
        %Card{card: "4", type: :hearts, deck: :blue, position: 3}
      ]

      refute Card.valid_sequence?(cards)
    end

    test "returns false for non-consecutive cards" do
      cards = [
        %Card{card: "Ace", type: :hearts, deck: :red, position: 0},
        %Card{card: "2", type: :hearts, deck: :blue, position: 1},
        %Card{card: "4", type: :hearts, deck: :red, position: 2},
        %Card{card: "5", type: :hearts, deck: :blue, position: 3}
      ]

      refute Card.valid_sequence?(cards)
    end

    test "returns false for less than 3 cards" do
      cards = [
        %Card{card: "Ace", type: :hearts, deck: :red, position: 0},
        %Card{card: "2", type: :hearts, deck: :blue, position: 1}
      ]

      refute Card.valid_sequence?(cards)
    end

    test "returns true for valid 3-card sequence" do
      cards = [
        %Card{card: "Ace", type: :hearts, deck: :red, position: 0},
        %Card{card: "2", type: :hearts, deck: :blue, position: 1},
        %Card{card: "3", type: :hearts, deck: :red, position: 2}
      ]

      assert Card.valid_sequence?(cards)
    end

    test "returns true for wrap-around sequence (Q-K-A)" do
      cards = [
        %Card{card: "Queen", type: :hearts, deck: :red, position: 0},
        %Card{card: "King", type: :hearts, deck: :blue, position: 1},
        %Card{card: "Ace", type: :hearts, deck: :red, position: 2}
      ]

      assert Card.valid_sequence?(cards)
    end

    test "returns true for wrap-around sequence (K-A-2)" do
      cards = [
        %Card{card: "King", type: :spades, deck: :red, position: 0},
        %Card{card: "Ace", type: :spades, deck: :blue, position: 1},
        %Card{card: "2", type: :spades, deck: :red, position: 2}
      ]

      assert Card.valid_sequence?(cards)
    end
  end

  describe "UI functions" do
    setup do
      card = %Card{card: "King", type: :spades, deck: :red, position: 5}
      {:ok, card: card}
    end

    test "display_name/1 returns abbreviated card names" do
      king_card = %Card{card: "King", type: :spades, deck: :red, position: 0}
      queen_card = %Card{card: "Queen", type: :hearts, deck: :blue, position: 1}
      jack_card = %Card{card: "Jack", type: :diamonds, deck: :red, position: 2}
      ace_card = %Card{card: "Ace", type: :clubs, deck: :blue, position: 3}
      ten_card = %Card{card: "10", type: :spades, deck: :red, position: 4}

      assert Card.display_name(king_card) == "K"
      assert Card.display_name(queen_card) == "Q"
      assert Card.display_name(jack_card) == "J"
      assert Card.display_name(ace_card) == "A"
      assert Card.display_name(ten_card) == "10"
    end

    test "suit_symbol/1 returns correct symbols" do
      assert Card.suit_symbol(:spades) == "♠"
      assert Card.suit_symbol(:hearts) == "♥"
      assert Card.suit_symbol(:diamonds) == "♦"
      assert Card.suit_symbol(:clubs) == "♣"
    end

    test "css_classes/1 returns proper CSS classes", %{card: card} do
      classes = Card.css_classes(card)
      # spades color
      assert String.contains?(classes, "text-gray-800")
      # red deck
      assert String.contains?(classes, "bg-red-50")
    end

    test "dom_id/1 generates DOM-safe identifier", %{card: card} do
      id = Card.dom_id(card)
      assert id == "card-5-king-spades-red"
    end
  end
end
