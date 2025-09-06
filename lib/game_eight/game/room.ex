defmodule GameEight.Game.Room do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "rooms" do
    field :name, :string
    field :type, :string
    field :status, :string, default: "pending"
    field :access_key, :string
    field :max_players, :integer, default: 6
    field :min_players, :integer, default: 2
    field :started_at, :utc_datetime
    field :finished_at, :utc_datetime
    field :timeout_minutes, :integer, default: 5

    belongs_to :creator, GameEight.Accounts.User
    has_many :room_users, GameEight.Game.RoomUser, preload_order: [asc: :position]
    has_many :users, through: [:room_users, :user]

    timestamps(type: :utc_datetime)
  end

  @types ~w(public private)
  @statuses ~w(pending started finished)

  @doc false
  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :type, :access_key, :max_players, :min_players, :timeout_minutes, :creator_id])
    |> validate_required([:type, :creator_id])
    |> validate_inclusion(:type, @types)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:max_players, greater_than: 1, less_than_or_equal_to: 6)
    |> validate_number(:min_players, greater_than: 1, less_than_or_equal_to: 6)
    |> validate_number(:timeout_minutes, greater_than: 0)
    |> validate_max_players_greater_than_min()
    |> maybe_generate_access_key()
    |> foreign_key_constraint(:creator_id)
  end

  @doc false
  def status_changeset(room, attrs) do
    room
    |> cast(attrs, [:status, :started_at, :finished_at])
    |> validate_inclusion(:status, @statuses)
    |> maybe_set_timestamp()
  end

  defp validate_max_players_greater_than_min(changeset) do
    max_players = get_field(changeset, :max_players)
    min_players = get_field(changeset, :min_players)

    if max_players && min_players && max_players < min_players do
      add_error(changeset, :max_players, "must be greater than or equal to min_players")
    else
      changeset
    end
  end

  defp maybe_generate_access_key(changeset) do
    type = get_field(changeset, :type)

    if type == "private" && is_nil(get_field(changeset, :access_key)) do
      put_change(changeset, :access_key, generate_access_key())
    else
      changeset
    end
  end

  defp maybe_set_timestamp(changeset) do
    status = get_change(changeset, :status)
    now = DateTime.utc_now(:second)

    case status do
      "started" -> put_change(changeset, :started_at, now)
      "finished" -> put_change(changeset, :finished_at, now)
      _ -> changeset
    end
  end

  defp generate_access_key do
    # Genera una clave de 8 caracteres alfanuméricos
    :crypto.strong_rand_bytes(6)
    |> Base.encode32()
    |> binary_part(0, 8)
  end

  @doc """
  Verifica si la sala puede iniciar el juego
  """
  def can_start?(room) do
    room.status == "pending" &&
      length(room.room_users) >= room.min_players &&
      length(room.room_users) <= room.max_players
  end

  @doc """
  Checks if the room is full
  """
  def is_full?(room) do
    case room.room_users do
      %Ecto.Association.NotLoaded{} ->
        # Si no está cargada la asociación, consultar la base de datos
        room_users_count = GameEight.Repo.one(
          from ru in GameEight.Game.RoomUser,
          where: ru.room_id == ^room.id,
          select: count(ru.id)
        )
        room_users_count >= room.max_players
      
      room_users when is_list(room_users) ->
        length(room_users) >= room.max_players
    end
  end

  @doc """
  Verifica si un usuario puede unirse a la sala
  """
  def can_join?(room, _user_id) do
    room.status == "pending" && !is_full?(room)
  end

  @doc """
  Obtiene la siguiente posición disponible en la sala
  """
  def next_position(room) do
    used_positions = case room.room_users do
      %Ecto.Association.NotLoaded{} ->
        # Si no está cargada la asociación, consultar la base de datos
        GameEight.Repo.all(
          from ru in GameEight.Game.RoomUser,
          where: ru.room_id == ^room.id,
          select: ru.position
        )
      
      room_users when is_list(room_users) ->
        Enum.map(room_users, & &1.position)
    end
    
    used_positions = Enum.sort(used_positions)
    
    Enum.find(0..(room.max_players - 1), fn pos ->
      pos not in used_positions
    end)
  end
end