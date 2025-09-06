defmodule GameEight.Game.EngineTest do
  use GameEight.DataCase, async: false

  alias GameEight.Game.{Engine, PlayerGameState}
  alias GameEight.{Game, Repo}

  import GameEight.AccountsFixtures

  describe "initialize_game/1" do
    test "creates game state and player states for valid room" do
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

      # Start room (this now also initializes the game)
      room = Repo.preload(room, [:creator, :room_users])
      {:ok, room} = Game.start_room(room)

      # Get the game state that was created by start_room
      game_state = Game.get_game_state_by_room(room.id)

      assert game_state.room_id == room.id
      assert game_state.status == "dice_rolling"
      assert game_state.max_players == 6
      assert game_state.cards_per_player == 8

      # Verify player states were created for both users
      player_states = Repo.all(PlayerGameState) |> Enum.filter(&(&1.game_state_id == game_state.id))
      assert length(player_states) == 2
    end

    test "fails for room that hasn't started" do
      user = user_fixture()

      {:ok, room} = Game.create_room(%{
        name: "Test Room",
        max_players: 4,
        creator_id: user.id,
        type: "public"
      })

      # Don't start the room
      assert {:error, :room_not_started} = Engine.initialize_game(room.id)
    end

    test "fails for room with insufficient players" do
      user = user_fixture()

      {:ok, room} = Game.create_room(%{
        name: "Test Room",
        max_players: 4,
        creator_id: user.id,
        type: "public"
      })

      # Add only one user
      {:ok, _} = Game.join_room(room, user)
      room = Repo.preload(room, [:creator, :room_users])

      # Force the room status to started for this test (normally start_room would fail)
      {:ok, room} = Repo.update(Ecto.Changeset.change(room, status: "started"))

      assert {:error, :insufficient_players} = Engine.initialize_game(room.id)
    end
  end

  describe "start_dice_phase/1" do
    test "transitions game to dice_rolling status" do
      # Create users
      user1 = user_fixture()
      user2 = user_fixture()

      # Create and setup room
      {:ok, room} = Game.create_room(%{
        name: "Test Room",
        max_players: 6,
        creator_id: user1.id,
        type: "public"
      })

      {:ok, _} = Game.join_room(room, user1)
      {:ok, _} = Game.join_room(room, user2)

      room = Repo.preload(room, [:creator, :room_users])
      {:ok, room} = Game.start_room(room)

      # Get the game state that was created by start_room (should already be in dice_rolling)
      game_state = Game.get_game_state_by_room(room.id)

      assert game_state.status == "dice_rolling"
    end
  end
end
