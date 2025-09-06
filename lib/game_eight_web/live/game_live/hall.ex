defmodule GameEightWeb.GameLive.Hall do
  use GameEightWeb, :live_view

  alias GameEight.Game

  @impl true
  def mount(_params, _session, socket) do
    # Versión simplificada para debug
    {:ok, assign(socket, :debug_test, "funcionando")}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, 
     socket
     |> assign(:page_title, "GameEight - Hall")}
  end

  @impl true
  def handle_event("join_room", %{"room_id" => room_id}, socket) do
    current_user = socket.assigns.current_scope.user

    case Game.get_room!(room_id) do
      room ->
        case Game.join_room(room, current_user) do
          {:ok, _room_user} ->
            {:noreply, 
             socket
             |> put_flash(:info, "Te has unido a la sala exitosamente")
             |> push_navigate(to: ~p"/rooms/#{room_id}")}

          {:error, :room_not_available} ->
            {:noreply, put_flash(socket, :error, "La sala no está disponible")}

          {:error, :already_in_room} ->
            {:noreply, 
             socket
             |> put_flash(:info, "Ya estás en esta sala")
             |> push_navigate(to: ~p"/rooms/#{room_id}")}

          {:error, :room_full} ->
            {:noreply, put_flash(socket, :error, "La sala está llena")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "No se pudo unir a la sala")}
        end
    end
  end

  @impl true
  def handle_event("join_private_room", %{"access_key" => access_key}, socket) do
    current_user = socket.assigns.current_scope.user

    case Game.join_private_room(access_key, current_user) do
      {:ok, room_user} ->
        {:noreply, 
         socket
         |> put_flash(:info, "Te has unido a la sala privada exitosamente")
         |> push_navigate(to: ~p"/rooms/#{room_user.room_id}")}

      {:error, :room_not_found} ->
        {:noreply, put_flash(socket, :error, "Clave de acceso inválida")}

      {:error, :room_not_available} ->
        {:noreply, put_flash(socket, :error, "La sala no está disponible")}

      {:error, :already_in_room} ->
        room = Game.get_room_by_access_key(access_key)
        {:noreply, 
         socket
         |> put_flash(:info, "Ya estás en esta sala")
         |> push_navigate(to: ~p"/rooms/#{room.id}")}

      {:error, :room_full} ->
        {:noreply, put_flash(socket, :error, "La sala está llena")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "No se pudo unir a la sala")}
    end
  end

  @impl true
  def handle_info({:room_created, room}, socket) do
    {:noreply, stream_insert(socket, :public_rooms, room, at: 0)}
  end

  @impl true
  def handle_info({:room_updated, room}, socket) do
    {:noreply, stream_insert(socket, :public_rooms, room)}
  end

  @impl true
  def handle_info({:room_deleted, room}, socket) do
    {:noreply, stream_delete(socket, :public_rooms, room)}
  end

  defp stream_configure(socket) do
    socket
    |> stream(:public_rooms, [])
  end

  defp load_public_rooms(socket) do
    public_rooms = Game.list_public_rooms()
    stream(socket, :public_rooms, public_rooms, reset: true)
  end

  defp room_players_text(room) do
    current = case room.room_users do
      users when is_list(users) -> length(users)
      _ -> 0
    end
    max = room.max_players
    "#{current}/#{max} jugadores"
  end

  defp room_status_badge_class(room) do
    case room.status do
      "pending" -> "badge-warning"
      "started" -> "badge-success"
      "finished" -> "badge-neutral"
    end
  end

  defp room_status_text(room) do
    case room.status do
      "pending" -> "Esperando"
      "started" -> "En juego"
      "finished" -> "Terminada"
    end
  end

  defp can_join_room?(room) do
    room_users_count = case room.room_users do
      users when is_list(users) -> length(users)
      _ -> 0
    end
    room.status == "pending" && room_users_count < room.max_players
  end
end