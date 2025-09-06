defmodule GameEight.Game do
  @moduledoc """
  The Game context.
  """

  import Ecto.Query, warn: false
  alias GameEight.Repo

  alias GameEight.Game.{Room, RoomUser, GameState}
  alias GameEight.Accounts.User

  @doc """
  Returns the list of rooms.

  ## Examples

      iex> list_rooms()
      [%Room{}, ...]

  """
  def list_rooms do
    Repo.all(Room)
  end

  @doc """
  Returns the list of public rooms that are pending.
  """
  def list_public_rooms do
    Room
    |> where([r], r.type == "public" and r.status == "pending")
    |> preload([:creator, room_users: :user])
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single room.

  Raises `Ecto.NoResultsError` if the Room does not exist.

  ## Examples

      iex> get_room!(123)
      %Room{}

      iex> get_room!(456)
      ** (Ecto.NoResultsError)

  """
  def get_room!(id) do
    Room
    |> preload([:creator, room_users: :user])
    |> Repo.get!(id)
  end

  @doc """
  Gets a room by access key.
  """
  def get_room_by_access_key(access_key) do
    Room
    |> where([r], r.access_key == ^access_key)
    |> preload([:creator, room_users: :user])
    |> Repo.one()
  end

  @doc """
  Gets a room with its users for game initialization.
  """
  def get_room_with_users(room_id) do
    case Room
         |> preload([:creator, room_users: :user])
         |> Repo.get(room_id) do
      nil -> {:error, :room_not_found}
      room -> {:ok, %{room | users: Enum.map(room.room_users, & &1.user)}}
    end
  end

  @doc """
  Creates a room.

  ## Examples

      iex> create_room(%{field: value})
      {:ok, %Room{}}

      iex> create_room(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_room(attrs \\ %{}) do
    %Room{}
    |> Room.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a room.

  ## Examples

      iex> update_room(room, %{field: new_value})
      {:ok, %Room{}}

      iex> update_room(room, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_room(%Room{} = room, attrs) do
    room
    |> Room.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates room status.
  """
  def update_room_status(%Room{} = room, status)
      when status in ["pending", "started", "finished"] do
    room
    |> Room.status_changeset(%{status: status})
    |> Repo.update()
  end

  @doc """
  Deletes a room.

  ## Examples

      iex> delete_room(room)
      {:ok, %Room{}}

      iex> delete_room(room)
      {:error, %Ecto.Changeset{}}

  """
  def delete_room(%Room{} = room) do
    Repo.delete(room)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking room changes.

  ## Examples

      iex> change_room(room)
      %Ecto.Changeset{data: %Room{}}

  """
  def change_room(%Room{} = room, attrs \\ %{}) do
    Room.changeset(room, attrs)
  end

  @doc """
  Joins a user to a room.
  """
  def join_room(%Room{} = room, %User{} = user) do
    # Cargar la sala con sus asociaciones para las validaciones
    room = room |> Repo.preload(:room_users)

    cond do
      !Room.can_join?(room, user.id) ->
        {:error, :room_not_available}

      user_in_room?(room.id, user.id) ->
        {:error, :already_in_room}

      true ->
        position = Room.next_position(room)

        if position do
          %RoomUser{}
          |> RoomUser.changeset(%{
            room_id: room.id,
            user_id: user.id,
            position: position
          })
          |> Repo.insert()
        else
          {:error, :room_full}
        end
    end
  end

  @doc """
  Joins a user to a private room using access key.
  """
  def join_private_room(access_key, %User{} = user) do
    case get_room_by_access_key(access_key) do
      nil ->
        {:error, :room_not_found}

      room ->
        join_room(room, user)
    end
  end

  @doc """
  Removes a user from a room.
  """
  def leave_room(%Room{} = room, %User{} = user) do
    case get_room_user(room.id, user.id) do
      nil ->
        {:error, :not_in_room}

      room_user ->
        Repo.delete(room_user)
    end
  end

  @doc """
  Updates the status of a user in a room.
  """
  def update_room_user_status(%Room{} = room, %User{} = user, status) do
    case get_room_user(room.id, user.id) do
      nil ->
        {:error, :not_in_room}

      room_user ->
        room_user
        |> RoomUser.status_changeset(%{status: status})
        |> Repo.update()
    end
  end

  @doc """
  Checks if a user is in a room.
  """
  def user_in_room?(room_id, user_id) do
    RoomUser
    |> where([ru], ru.room_id == ^room_id and ru.user_id == ^user_id)
    |> Repo.exists?()
  end

  @doc """
  Gets a room user relationship.
  """
  def get_room_user(room_id, user_id) do
    RoomUser
    |> where([ru], ru.room_id == ^room_id and ru.user_id == ^user_id)
    |> Repo.one()
  end

  @doc """
  Gets users in a room ordered by position.
  """
  def get_room_users(room_id) do
    RoomUser
    |> where([ru], ru.room_id == ^room_id)
    |> order_by([ru], asc: ru.position)
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Starts a room if conditions are met.
  """
  def start_room(%Room{} = room) do
    cond do
      room.status != "pending" ->
        {:error, :room_not_pending}

      !Room.can_start?(room) ->
        {:error, :insufficient_players}

      true ->
        case update_room_status(room, "started") do
          {:ok, started_room} ->
            # Initialize the game state when room starts
            case GameEight.Game.Engine.initialize_game(room.id) do
              {:ok, _game_state} ->
                {:ok, started_room}

              {:error, reason} ->
                # Rollback room status if game initialization fails
                update_room_status(started_room, "pending")
                {:error, reason}
            end

          error ->
            error
        end
    end
  end

  @doc """
  Checks if a room should auto-start based on timeout.
  """
  def should_auto_start?(%Room{} = room) do
    if room.status == "pending" && Room.can_start?(room) do
      # Calcular si han pasado los minutos de timeout desde que se unió el primer jugador
      first_player_joined =
        room.room_users
        |> Enum.min_by(& &1.joined_at, DateTime)
        |> Map.get(:joined_at)

      timeout_seconds = room.timeout_minutes * 60
      elapsed_seconds = DateTime.diff(DateTime.utc_now(), first_player_joined, :second)

      elapsed_seconds >= timeout_seconds
    else
      false
    end
  end

  @doc """
  Gets rooms that should auto-start.
  """
  def get_rooms_to_auto_start do
    # Esta función sería llamada por un proceso periódico
    Room
    |> where([r], r.status == "pending")
    |> preload([:room_users])
    |> Repo.all()
    |> Enum.filter(&should_auto_start?/1)
  end

  @doc """
  Finishes a room.
  """
  def finish_room(%Room{} = room) do
    update_room_status(room, "finished")
  end

  @doc """
  Gets all active rooms for a user.
  """
  def get_user_active_rooms(user_id) do
    Room
    |> join(:inner, [r], ru in RoomUser, on: ru.room_id == r.id)
    |> where([r, ru], ru.user_id == ^user_id and ru.status == "active")
    |> where([r], r.status in ["pending", "started"])
    |> preload([:creator, room_users: :user])
    |> Repo.all()
  end

  @doc """
  Gets room statistics.
  """
  def get_room_stats(room_id) do
    room = get_room!(room_id)
    room_users = get_room_users(room_id)

    %{
      total_players: length(room_users),
      active_players: Enum.count(room_users, &(&1.status == "active")),
      positions_filled: Enum.map(room_users, & &1.position) |> Enum.sort(),
      can_start: Room.can_start?(room |> Repo.preload(:room_users)),
      is_full: Room.is_full?(room |> Repo.preload(:room_users))
    }
  end

  @doc """
  Checks if room has expired (for cleanup purposes).
  """
  def room_expired?(%Room{} = room, hours_threshold \\ 24) do
    case room.status do
      "finished" ->
        # Salas terminadas que han estado así por más del threshold
        if room.finished_at do
          elapsed_hours = DateTime.diff(DateTime.utc_now(), room.finished_at, :hour)
          elapsed_hours >= hours_threshold
        else
          false
        end

      "pending" ->
        # Salas pendientes que han estado así por más del threshold
        elapsed_hours = DateTime.diff(DateTime.utc_now(), room.inserted_at, :hour)
        elapsed_hours >= hours_threshold

      _ ->
        false
    end
  end

  @doc """
  Clean up expired rooms.
  """
  def cleanup_expired_rooms(hours_threshold \\ 24) do
    expired_rooms =
      Room
      |> Repo.all()
      |> Enum.filter(&room_expired?(&1, hours_threshold))

    deleted_count =
      expired_rooms
      |> Enum.map(&delete_room/1)
      |> Enum.count(fn
        {:ok, _} -> true
        _ -> false
      end)

    {:ok, deleted_count}
  end

  @doc """
  Gets a game state by room ID.
  """
  def get_game_state_by_room(room_id) do
    GameState
    |> where([gs], gs.room_id == ^room_id)
    |> Repo.one()
  end

  @doc """
  Gets a game state with all its associations preloaded.
  """
  def get_game_state_with_players(game_state_id) do
    case Repo.get(GameState, game_state_id)
         |> Repo.preload(player_game_states: :user) do
      nil -> {:error, :game_not_found}
      game_state -> {:ok, game_state}
    end
  end
end
