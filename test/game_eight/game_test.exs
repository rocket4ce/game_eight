defmodule GameEight.GameTest do
  use GameEight.DataCase

  alias GameEight.Game
  alias GameEight.Game.{Room, RoomUser}

  describe "rooms" do
    @valid_attrs %{
      name: "Test Room",
      type: "public"
    }

    @invalid_attrs %{
      type: "invalid_type"
    }

    def user_fixture(attrs \\ %{}) do
      {:ok, user} =
        attrs
        |> Enum.into(%{
          email: "test#{System.unique_integer([:positive])}@example.com",
          password: "hello world!"
        })
        |> GameEight.Accounts.register_user()

      user
    end

    def room_fixture(attrs \\ %{}) do
      user = user_fixture()

      {:ok, room} =
        attrs
        |> Enum.into(Map.put(@valid_attrs, :creator_id, user.id))
        |> Game.create_room()

      # Unir al creador a la sala
      {:ok, _room_user} = Game.join_room(room, user)
      
      %{room | creator: user}
    end

    test "list_rooms/0 returns all rooms" do
      room = room_fixture()
      rooms = Game.list_rooms()
      assert length(rooms) == 1
      assert hd(rooms).id == room.id
    end

    test "get_room!/1 returns the room with given id" do
      room = room_fixture()
      retrieved_room = Game.get_room!(room.id)
      assert retrieved_room.id == room.id
    end

    test "create_room/1 with valid data creates a room" do
      user = user_fixture()
      attrs = Map.put(@valid_attrs, :creator_id, user.id)

      assert {:ok, %Room{} = room} = Game.create_room(attrs)
      assert room.name == "Test Room"
      assert room.type == "public"
      assert room.status == "pending"
      assert room.creator_id == user.id
    end

    test "create_room/1 with private type generates access key" do
      user = user_fixture()
      attrs = %{name: "Private Room", type: "private", creator_id: user.id}

      assert {:ok, %Room{} = room} = Game.create_room(attrs)
      assert room.type == "private"
      assert is_binary(room.access_key)
      assert String.length(room.access_key) == 8
    end

    test "create_room/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Game.create_room(@invalid_attrs)
    end

    test "join_room/2 allows user to join a room" do
      room = room_fixture()
      user = user_fixture()

      assert {:ok, %RoomUser{} = room_user} = Game.join_room(room, user)
      assert room_user.room_id == room.id
      assert room_user.user_id == user.id
      assert room_user.position == 1  # Creador está en posición 0
    end

    test "join_room/2 assigns correct positions" do
      room = room_fixture()
      user1 = user_fixture()
      user2 = user_fixture()

      {:ok, room_user1} = Game.join_room(room, user1)
      {:ok, room_user2} = Game.join_room(room, user2)

      assert room_user1.position == 1  # Creador en 0, primer usuario en 1
      assert room_user2.position == 2  # Segundo usuario en 2
    end

    test "join_room/2 prevents duplicate joins" do
      room = room_fixture()
      user = user_fixture()

      {:ok, _room_user} = Game.join_room(room, user)
      assert {:error, :already_in_room} = Game.join_room(room, user)
    end
  end
end