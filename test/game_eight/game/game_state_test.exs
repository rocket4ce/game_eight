defmodule GameEight.Game.GameStateTest do
  use GameEight.DataCase

  alias GameEight.Game.{GameState, PlayerGameState, Card}
  import GameEight.GameFixtures
  import GameEight.AccountsFixtures

  describe "GameState schema" do
    test "creates a valid game state" do
      user = user_fixture()
      room = room_fixture(creator: user)

      attrs = %{
        room_id: room.id,
        status: "initializing",
        max_players: 4,
        cards_per_player: 8
      }

      changeset = GameState.changeset(%GameState{}, attrs)
      assert changeset.valid?

      {:ok, game_state} = Repo.insert(changeset)
      assert game_state.room_id == room.id
      assert game_state.status == "initializing"
      assert game_state.max_players == 4
    end

    test "validates status inclusion" do
      changeset = GameState.changeset(%GameState{}, %{status: "invalid_status"})
      refute changeset.valid?
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "deck_to_cards converts maps to Card structs" do
      cards = [
        %{position: 0, card: "Ace", type: :spades, deck: :red},
        %{position: 1, card: "King", type: :hearts, deck: :blue}
      ]

      game_state = %GameState{deck: %{"cards" => cards}}
      card_structs = GameState.deck_to_cards(game_state)

      assert length(card_structs) == 2
      assert %Card{position: 0, card: "Ace"} = hd(card_structs)
    end

    test "cards_to_deck converts Card structs to maps" do
      cards = [
        %Card{position: 0, card: "Ace", type: :spades, deck: :red},
        %Card{position: 1, card: "King", type: :hearts, deck: :blue}
      ]

      deck_map = GameState.cards_to_deck(cards)
      assert %{"cards" => [%{position: 0, card: "Ace"} | _]} = deck_map
    end
  end

  describe "PlayerGameState schema" do
    test "creates a valid player game state" do
      user = user_fixture()
      room = room_fixture(creator: user)
      game_state = game_state_fixture(room: room)

      attrs = %{
        game_state_id: game_state.id,
        user_id: user.id,
        player_index: 0,
        player_status: "player_off"
      }

      changeset = PlayerGameState.changeset(%PlayerGameState{}, attrs)
      assert changeset.valid?

      {:ok, player_state} = Repo.insert(changeset)
      assert player_state.player_index == 0
      assert player_state.player_status == "player_off"
    end

    test "validates dice roll range" do
      changeset = PlayerGameState.dice_changeset(%PlayerGameState{}, %{dice_roll: 7})
      refute changeset.valid?
      assert %{dice_roll: ["must be less than or equal to 6"]} = errors_on(changeset)
    end

    test "hand_to_cards converts hand maps to Card structs" do
      cards = [
        %{position: 0, card: "Ace", type: :spades, deck: :red},
        %{position: 1, card: "King", type: :hearts, deck: :blue}
      ]

      player_state = %PlayerGameState{hand_cards: %{"cards" => cards}}
      card_structs = PlayerGameState.hand_to_cards(player_state)

      assert length(card_structs) == 2
      assert %Card{position: 0, card: "Ace"} = hd(card_structs)
    end

    test "has_won? checks for empty hand" do
      player_with_cards = %PlayerGameState{hand_cards: %{"cards" => [%{}]}}
      player_without_cards = %PlayerGameState{hand_cards: %{"cards" => []}}

      refute PlayerGameState.has_won?(player_with_cards)
      assert PlayerGameState.has_won?(player_without_cards)
    end
  end
end
