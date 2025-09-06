defmodule GameEight.Game.RoomUser do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "room_users" do
    field :position, :integer
    field :joined_at, :utc_datetime
    field :status, :string, default: "active"

    belongs_to :room, GameEight.Game.Room
    belongs_to :user, GameEight.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @statuses ~w(active disconnected left)

  @doc false
  def changeset(room_user, attrs) do
    room_user
    |> cast(attrs, [:position, :room_id, :user_id, :joined_at, :status])
    |> validate_required([:position, :room_id, :user_id])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:position, greater_than_or_equal_to: 0, less_than: 6)
    |> unique_constraint([:room_id, :user_id])
    |> unique_constraint([:room_id, :position])
    |> foreign_key_constraint(:room_id)
    |> foreign_key_constraint(:user_id)
    |> maybe_set_joined_at()
  end

  @doc false
  def status_changeset(room_user, attrs) do
    room_user
    |> cast(attrs, [:status])
    |> validate_inclusion(:status, @statuses)
  end

  defp maybe_set_joined_at(changeset) do
    if is_nil(get_field(changeset, :joined_at)) do
      put_change(changeset, :joined_at, DateTime.utc_now(:second))
    else
      changeset
    end
  end
end