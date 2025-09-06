defmodule GameEightWeb.GameLive.RoomShow do
  use GameEightWeb, :live_view

  alias GameEight.Game

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    room = Game.get_room!(id)
    current_user = socket.assigns.current_scope.user

    if connected?(socket) do
      # Suscribirse a actualizaciones de esta sala específica
      Phoenix.PubSub.subscribe(GameEight.PubSub, "room:#{id}")
    end

    {:noreply,
     socket
     |> assign(:room, room)
     |> assign(:page_title, "Sala: #{room.name}")
     |> assign(:current_user_in_room, user_in_room?(room, current_user.id))
     |> assign(:room_stats, Game.get_room_stats(id))}
  end

  @impl true
  def handle_event("join_room", _params, socket) do
    room = socket.assigns.room
    current_user = socket.assigns.current_scope.user

    case Game.join_room(room, current_user) do
      {:ok, _room_user} ->
        updated_room = Game.get_room!(room.id)
        Phoenix.PubSub.broadcast(GameEight.PubSub, "room:#{room.id}", {:room_updated, updated_room})
        
        {:noreply,
         socket
         |> put_flash(:info, "Te has unido a la sala exitosamente")
         |> assign(:room, updated_room)
         |> assign(:current_user_in_room, true)
         |> assign(:room_stats, Game.get_room_stats(room.id))}

      {:error, :already_in_room} ->
        {:noreply, put_flash(socket, :info, "Ya estás en esta sala")}

      {:error, :room_not_available} ->
        {:noreply, put_flash(socket, :error, "La sala no está disponible")}

      {:error, :room_full} ->
        {:noreply, put_flash(socket, :error, "La sala está llena")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "No se pudo unir a la sala")}
    end
  end

  @impl true
  def handle_event("leave_room", _params, socket) do
    room = socket.assigns.room
    current_user = socket.assigns.current_scope.user

    case Game.leave_room(room, current_user) do
      {:ok, _} ->
        updated_room = Game.get_room!(room.id)
        Phoenix.PubSub.broadcast(GameEight.PubSub, "room:#{room.id}", {:room_updated, updated_room})
        
        {:noreply,
         socket
         |> put_flash(:info, "Has salido de la sala")
         |> push_navigate(to: ~p"/rooms")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "No se pudo salir de la sala")}
    end
  end

  @impl true
  def handle_event("start_room", _params, socket) do
    room = socket.assigns.room
    current_user = socket.assigns.current_scope.user

    if room.creator_id == current_user.id do
      case Game.start_room(room) do
        {:ok, started_room} ->
          Phoenix.PubSub.broadcast(GameEight.PubSub, "room:#{room.id}", {:room_started, started_room})
          
          {:noreply,
           socket
           |> put_flash(:info, "¡Partida iniciada!")
           |> assign(:room, started_room)
           |> assign(:room_stats, Game.get_room_stats(room.id))}

        {:error, :insufficient_players} ->
          {:noreply, put_flash(socket, :error, "Se necesitan al menos #{room.min_players} jugadores para iniciar")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "No se pudo iniciar la partida")}
      end
    else
      {:noreply, put_flash(socket, :error, "Solo el creador puede iniciar la partida")}
    end
  end

  @impl true
  def handle_event("delete_room", _params, socket) do
    room = socket.assigns.room
    current_user = socket.assigns.current_scope.user

    if room.creator_id == current_user.id && room.status == "pending" do
      case Game.delete_room(room) do
        {:ok, _} ->
          Phoenix.PubSub.broadcast(GameEight.PubSub, "rooms", {:room_deleted, room})
          
          {:noreply,
           socket
           |> put_flash(:info, "Sala eliminada exitosamente")
           |> push_navigate(to: ~p"/rooms")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "No se pudo eliminar la sala")}
      end
    else
      {:noreply, put_flash(socket, :error, "Solo el creador puede eliminar salas pendientes")}
    end
  end

  @impl true
  def handle_info({:room_updated, updated_room}, socket) do
    {:noreply, 
     socket
     |> assign(:room, updated_room)
     |> assign(:room_stats, Game.get_room_stats(updated_room.id))}
  end

  @impl true
  def handle_info({:room_started, started_room}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "¡La partida ha comenzado!")
     |> assign(:room, started_room)
     |> assign(:room_stats, Game.get_room_stats(started_room.id))}
  end

  defp user_in_room?(room, user_id) do
    Enum.any?(room.room_users, &(&1.user_id == user_id))
  end

  defp is_room_creator?(room, user_id), do: room.creator_id == user_id

  defp room_status_text("pending"), do: "Esperando jugadores"
  defp room_status_text("started"), do: "Partida en curso"
  defp room_status_text("finished"), do: "Partida terminada"

  defp room_status_badge_class("pending"), do: "badge-warning"
  defp room_status_badge_class("started"), do: "badge-success"
  defp room_status_badge_class("finished"), do: "badge-neutral"

  defp room_type_text("public"), do: "Pública"
  defp room_type_text("private"), do: "Privada"

  defp can_join_room?(room, current_user_in_room) do
    room.status == "pending" && !current_user_in_room && !Game.Room.is_full?(room)
  end

  defp can_start_room?(room, user_id) do
    is_room_creator?(room, user_id) && 
    room.status == "pending" && 
    Game.Room.can_start?(room)
  end

  defp user_position_in_room(room, user_id) do
    case Enum.find(room.room_users, &(&1.user_id == user_id)) do
      nil -> nil
      room_user -> room_user.position
    end
  end

  defp format_datetime(datetime) do
    case datetime do
      nil -> "N/A"
      dt -> Calendar.strftime(dt, "%d/%m/%Y %H:%M")
    end
  end

  defp time_since_created(room) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, room.inserted_at, :second)
    
    cond do
      diff_seconds < 60 -> "#{diff_seconds} segundos"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)} minutos"
      true -> "#{div(diff_seconds, 3600)} horas"
    end
  end
end