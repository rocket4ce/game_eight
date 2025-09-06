defmodule GameEight.Game.EngineTest do
  use GameEight.DataCase, async: false

  alias GameEight.Game.{Engine, GameState, PlayerGameState, Card}
  alias GameEight.{Game, Accounts}

  describe "initialize_game/1" do
    test "creates game state and player states for valid room" do
      # Create users and room
      user1 = Accounts.create_user!(%{username: "player1", email: "player1@test.com"})
      user2 = Accounts.create_user!(%{username: "player2", email: "player2@test.com"})

      room = Game.create_room!(%{
        name: "Test Room",
        max_players: 4,
        creator_id: user1.id,
        status: "started"
      })

      Game.add_user_to_room!(room.id, user1.id)
      Game.add_user_to_room!(room.id, user2.id)

      # Initialize game
      {:ok, game_state} = Engine.initialize_game(room.id)

      assert game_state.room_id == room.id
      assert game_state.status == "initializing"
      assert game_state.max_players == 4
      assert game_state.cards_per_player == 8

      # Verify player states were created
      player_states = Repo.all(PlayerGameState) |> Enum.filter(&(&1.game_state_id == game_state.id))
      assert length(player_states) == 2
    end

    test "fails for room that hasn't started" do
      user = Accounts.create_user!(%{username: "player1", email: "player1@test.com"})

      room = Game.create_room!(%{
        name: "Test Room",
        max_players: 4,
        creator_id: user.id,
        status: "waiting"
      })

      assert {:error, :room_not_started} = Engine.initialize_game(room.id)
    end

    test "fails for room with insufficient players" do
      user = Accounts.create_user!(%{username: "player1", email: "player1@test.com"})

      room = Game.create_room!(%{
        name: "Test Room",
        max_players: 4,
        creator_id: user.id,
        status: "started"
      })

      Game.add_user_to_room!(room.id, user.id)

      assert {:error, :insufficient_players} = Engine.initialize_game(room.id)
    end
  end

  describe "start_dice_phase/1" do
    setup do
      user1 = Accounts.create_user!(%{username: "player1", email: "player1@test.com"})
      user2 = Accounts.create_user!(%{username: "player2", email: "player2@test.com"})

      room = Game.create_room!(%{
        name: "Test Room",
        max_players: 4,
        creator_id: user1.id,
        status: "started"
      })

      Game.add_user_to_room!(room.id, user1.id)
      Game.add_user_to_room!(room.id, user2.id)

      {:ok, game_state} = Engine.initialize_game(room.id)

      %{game_state: game_state, user1: user1, user2: user2}
    end

    test "transitions game to dice_rolling status", %{game_state: game_state} do
      {:ok, updated_game} = Engine.start_dice_phase(game_state.id)
      assert updated_game.status == "dice_rolling"
    end
  end

  describe "roll_dice/3" do
    setup do
      user1 = Accounts.create_user!(%{username: "player1", email: "player1@test.com"})
      user2 = Accounts.create_user!(%{username: "player2", email: "player2@test.com"})

      room = Game.create_room!(%{
        name: "Test Room",
        max_players: 4,
        creator_id: user1.id,
        status: "started"
      })

      Game.add_user_to_room!(room.id, user1.id)
      Game.add_user_to_room!(room.id, user2.id)

      {:ok, game_state} = Engine.initialize_game(room.id)
      {:ok, game_state} = Engine.start_dice_phase(game_state.id)

      %{game_state: game_state, user1: user1, user2: user2}
    end

    test "records player dice roll", %{game_state: game_state, user1: user1} do
      {:ok, updated_game} = Engine.roll_dice(game_state.id, user1.id, 5)

      assert Map.get(updated_game.dice_results, to_string(user1.id)) == 5
    end

    test "starts game when all players have rolled", %{game_state: game_state, user1: user1, user2: user2} do
      # Both players roll dice
      {:ok, game_after_first} = Engine.roll_dice(game_state.id, user1.id, 5)
      {:ok, game_after_second} = Engine.roll_dice(game_after_first.id, user2.id, 3)

      # Game should have started
      assert game_after_second.status == "playing"
      assert length(game_after_second.turn_order) == 2
      assert game_after_second.current_player_index == 0
    end

    test "rejects invalid dice values", %{game_state: game_state, user1: user1} do
      assert_raise FunctionClauseError, fn ->
        Engine.roll_dice(game_state.id, user1.id, 7)
      end

      assert_raise FunctionClauseError, fn ->
        Engine.roll_dice(game_state.id, user1.id, 0)
      end
    end
  end

  describe "play_cards/5" do
    setup do
      user1 = Accounts.create_user!(%{username: "player1", email: "player1@test.com"})
      user2 = Accounts.create_user!(%{username: "player2", email: "player2@test.com"})

      room = Game.create_room!(%{
        name: "Test Room",
        max_players: 4,
        creator_id: user1.id,
        status: "started"
      })

      Game.add_user_to_room!(room.id, user1.id)
      Game.add_user_to_room!(room.id, user2.id)

      {:ok, game_state} = Engine.initialize_game(room.id)
      {:ok, game_state} = Engine.start_dice_phase(game_state.id)
      {:ok, game_state} = Engine.roll_dice(game_state.id, user1.id, 6)
      {:ok, game_state} = Engine.roll_dice(game_state.id, user2.id, 3)

      %{game_state: game_state, user1: user1, user2: user2}
    end

    test "validates turn order", %{game_state: game_state, user2: user2} do
      # Create some cards to play
      cards = [
        %Card{position: 1, card: "5", type: :hearts, deck: :red},
        %Card{position: 2, card: "6", type: :hearts, deck: :red},
        %Card{position: 3, card: "7", type: :hearts, deck: :red}
      ]

      # user2 tries to play out of turn (user1 should be first due to higher dice)
      assert {:error, :not_your_turn} = Engine.play_cards(game_state.id, user2.id, cards, "sequence")
    end
  end

  describe "draw_card/2" do
    setup do
      user1 = Accounts.create_user!(%{username: "player1", email: "player1@test.com"})
      user2 = Accounts.create_user!(%{username: "player2", email: "player2@test.com"})

      room = Game.create_room!(%{
        name: "Test Room",
        max_players: 4,
        creator_id: user1.id,
        status: "started"
      })

      Game.add_user_to_room!(room.id, user1.id)
      Game.add_user_to_room!(room.id, user2.id)

      {:ok, game_state} = Engine.initialize_game(room.id)
      {:ok, game_state} = Engine.start_dice_phase(game_state.id)
      {:ok, game_state} = Engine.roll_dice(game_state.id, user1.id, 6)
      {:ok, game_state} = Engine.roll_dice(game_state.id, user2.id, 3)

      %{game_state: game_state, user1: user1, user2: user2}
    end

    test "validates turn order for drawing", %{game_state: game_state, user2: user2} do
      # user2 tries to draw out of turn
      assert {:error, :not_your_turn} = Engine.draw_card(game_state.id, user2.id)
    end
  end
end
