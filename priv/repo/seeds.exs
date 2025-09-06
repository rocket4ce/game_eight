# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     GameEight.Repo.insert!(%GameEight.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

import Ecto.Query
alias GameEight.Repo
alias GameEight.Accounts
alias GameEight.Game

# Crear usuarios de ejemplo
users = [
  %{email: "player1@example.com", password: "securepassword123"},
  %{email: "player2@example.com", password: "securepassword123"},
  %{email: "player3@example.com", password: "securepassword123"},
  %{email: "player4@example.com", password: "securepassword123"}
]

created_users = 
  Enum.map(users, fn user_attrs ->
    case Accounts.register_user(user_attrs) do
      {:ok, user} -> user
      {:error, _} ->
        # Si el usuario ya existe, lo obtenemos
        Accounts.get_user_by_email(user_attrs.email)
    end
  end)

[user1, user2, user3, user4] = created_users

# Crear salas de ejemplo
IO.puts("Creating example rooms...")

# Sala pública con algunos jugadores
{:ok, public_room} = Game.create_room(%{
  name: "Sala Pública - El Ocho",
  type: "public",
  creator_id: user1.id
})

{:ok, _} = Game.join_room(public_room, user1)
{:ok, _} = Game.join_room(public_room, user2)

# Sala privada
{:ok, private_room} = Game.create_room(%{
  name: "Sala Privada - Amigos",
  type: "private",
  creator_id: user3.id
})

{:ok, _} = Game.join_room(private_room, user3)
{:ok, _} = Game.join_room(private_room, user4)

IO.puts("✅ Seeds completed!")
IO.puts("Public room ID: #{public_room.id}")
IO.puts("Private room access key: #{private_room.access_key}")

# Mostrar estadísticas
public_stats = Game.get_room_stats(public_room.id)
private_stats = Game.get_room_stats(private_room.id)

IO.puts("\n📊 Room Statistics:")
IO.puts("Public room: #{public_stats.total_players} players, can start: #{public_stats.can_start}")
IO.puts("Private room: #{private_stats.total_players} players, can start: #{private_stats.can_start}")
