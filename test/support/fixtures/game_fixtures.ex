defmodule GameEight.GameFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `GameEight.Game` context.
  """

  alias GameEight.Game
  alias GameEight.Repo

  def room_fixture(attrs \\ %{}) do
    creator = attrs[:creator] || GameEight.AccountsFixtures.user_fixture()

    {:ok, room} =
      attrs
      |> Enum.into(%{
        name: "Test Room",
        type: "public",
        creator_id: creator.id,
        max_players: 6,
        min_players: 2
      })
      |> Game.create_room()

    room
  end

  def game_state_fixture(attrs \\ %{}) do
    room = attrs[:room] || room_fixture()

    game_state_attrs =
      attrs
      |> Enum.into(%{
        room_id: room.id,
        status: "initializing",
        max_players: 6,
        cards_per_player: 8
      })

    %Game.GameState{}
    |> Game.GameState.changeset(game_state_attrs)
    |> Repo.insert!()
  end

  def player_game_state_fixture(attrs \\ %{}) do
    game_state = attrs[:game_state] || game_state_fixture()
    user = attrs[:user] || GameEight.AccountsFixtures.user_fixture()
    player_index = attrs[:player_index] || 0

    player_attrs =
      attrs
      |> Enum.into(%{
        game_state_id: game_state.id,
        user_id: user.id,
        player_index: player_index,
        player_status: "player_off"
      })

    %Game.PlayerGameState{}
    |> Game.PlayerGameState.changeset(player_attrs)
    |> Repo.insert!()
  end
end
