defmodule GameEight.Game.EngineCardDealingTest do
  use GameEight.DataCase, async: false

  alias GameEight.Game.{Engine, PlayerGameState}
  alias GameEight.{Game, Repo}

  import GameEight.AccountsFixtures

  describe "card dealing after dice phase" do
    test "deals 8 cards to each player after all dice are rolled" do
      # Create users
      user1 = user_fixture()
      user2 = user_fixture()

      # Create room
      {:ok, room} = Game.create_room(%{
        name: "Test Room",
        max_players: 6,
        creator_id: user1.id,
        type: "public"
      })

      # Add users to room
      {:ok, _} = Game.join_room(room, user1)
      {:ok, _} = Game.join_room(room, user2)

      # Start room (this creates game in dice_rolling status)
      room = Repo.preload(room, [:creator, :room_users])
      {:ok, room} = Game.start_room(room)

      # Get the game state
      game_state = Game.get_game_state_by_room(room.id)
      assert game_state.status == "dice_rolling"

      # Both players roll dice
      {:ok, game_state} = Engine.roll_dice(game_state.id, user1.id, 6)
      {:ok, game_state} = Engine.roll_dice(game_state.id, user2.id, 4)

      # After both players roll dice, game should transition to "playing"
      assert game_state.status == "playing"

      # Verify that both players have 8 cards
      player_states = Repo.all(PlayerGameState) |> Enum.filter(&(&1.game_state_id == game_state.id))
      assert length(player_states) == 2

      for player_state <- player_states do
        # Reload to get updated hand_cards
        player_state = Repo.reload(player_state)
        hand_cards = Map.get(player_state.hand_cards, "cards", [])
        assert length(hand_cards) == 8, "Player #{player_state.user_id} should have 8 cards, got #{length(hand_cards)}"
      end

      # Verify deck has remaining cards (104 total - 16 dealt = 88 remaining)
      deck_cards = Map.get(game_state.deck, "cards", [])
      assert length(deck_cards) == 88, "Deck should have 88 cards remaining, got #{length(deck_cards)}"
    end

    test "turn order is determined by highest dice roll" do
      # Create users
      user1 = user_fixture()
      user2 = user_fixture()
      user3 = user_fixture()

      # Create room
      {:ok, room} = Game.create_room(%{
        name: "Test Room",
        max_players: 6,
        creator_id: user1.id,
        type: "public"
      })

      # Add users to room
      {:ok, _} = Game.join_room(room, user1)
      {:ok, _} = Game.join_room(room, user2)
      {:ok, _} = Game.join_room(room, user3)

      # Start room
      room = Repo.preload(room, [:creator, :room_users])
      {:ok, room} = Game.start_room(room)

      # Get the game state
      game_state = Game.get_game_state_by_room(room.id)

      # Players roll dice with different values
      {:ok, game_state} = Engine.roll_dice(game_state.id, user1.id, 3)
      {:ok, game_state} = Engine.roll_dice(game_state.id, user2.id, 6)
      {:ok, game_state} = Engine.roll_dice(game_state.id, user3.id, 1)

      # After all players roll dice, game should transition to "playing"
      assert game_state.status == "playing"

      # user2 should start (highest dice roll = 6)
      first_player_id = List.first(game_state.turn_order)
      assert first_player_id == user2.id

      # Verify turn order: user2 (6), user1 (3), user3 (1)
      assert game_state.turn_order == [user2.id, user1.id, user3.id]

      # Current player should be the first in turn order (index 0)
      assert game_state.current_player_index == 0

      # The current player ID should match the first player in turn order
      current_player_id = GameEight.Game.GameState.current_player_id(game_state)
      assert current_player_id == user2.id
    end
  end
end
