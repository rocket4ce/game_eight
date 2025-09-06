defmodule GameEightWeb.GameLive.RoomIndex do
  use GameEightWeb, :live_view

  alias GameEight.Game
  alias GameEight.Game.Room

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> stream(:rooms, []) |> assign(:rooms_empty?, true)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    current_user = socket.assigns.current_scope.user
    user_rooms = Game.get_user_active_rooms(current_user.id)

    socket
    |> assign(:page_title, "Mis Salas")
    |> assign(:rooms_empty?, user_rooms == [])
    |> stream(:rooms, user_rooms, reset: true)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Nueva Sala")
    |> assign(:room, %Room{})
    |> assign(:form, to_form(Game.change_room(%Room{})))
  end

  @impl true
  def handle_event("validate", %{"room" => room_params}, socket) do
    changeset = Game.change_room(%Room{}, room_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  @impl true
  def handle_event("save", %{"room" => room_params}, socket) do
    current_user = socket.assigns.current_scope.user
    room_params = Map.put(room_params, "creator_id", current_user.id)

    case Game.create_room(room_params) do
      {:ok, room} ->
        # Unir automáticamente al creador
        {:ok, _room_user} = Game.join_room(room, current_user)

        # Notificar a todos los usuarios sobre la nueva sala
        if room.type == "public" do
          Phoenix.PubSub.broadcast(GameEight.PubSub, "rooms", {:room_created, room})
        end

        {:noreply,
         socket
         |> put_flash(:info, "Sala creada exitosamente")
         |> push_navigate(to: ~p"/rooms/#{room.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    room = Game.get_room!(id)
    current_user = socket.assigns.current_scope.user

    # Solo el creador puede eliminar la sala
    if room.creator_id == current_user.id do
      case Game.delete_room(room) do
        {:ok, _} ->
          Phoenix.PubSub.broadcast(GameEight.PubSub, "rooms", {:room_deleted, room})

          # Reload rooms to check if empty
          current_user = socket.assigns.current_scope.user
          remaining_rooms = Game.get_user_active_rooms(current_user.id)

          {:noreply,
           socket
           |> put_flash(:info, "Sala eliminada exitosamente")
           |> assign(:rooms_empty?, remaining_rooms == [])
           |> stream_delete(:rooms, room)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "No se pudo eliminar la sala")}
      end
    else
      {:noreply, put_flash(socket, :error, "Solo el creador puede eliminar la sala")}
    end
  end

  @impl true
  def handle_event("leave", %{"id" => id}, socket) do
    room = Game.get_room!(id)
    current_user = socket.assigns.current_scope.user

    case Game.leave_room(room, current_user) do
      {:ok, _} ->
        # Reload rooms to check if empty
        remaining_rooms = Game.get_user_active_rooms(current_user.id)

        {:noreply,
         socket
         |> put_flash(:info, "Has salido de la sala")
         |> assign(:rooms_empty?, remaining_rooms == [])
         |> stream_delete(:rooms, room)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "No se pudo salir de la sala")}
    end
  end

  @impl true
  def handle_event("start", %{"id" => id}, socket) do
    room = Game.get_room!(id)
    current_user = socket.assigns.current_scope.user

    # Solo el creador puede iniciar la partida
    if room.creator_id == current_user.id do
      case Game.start_room(room) do
        {:ok, started_room} ->
          Phoenix.PubSub.broadcast(GameEight.PubSub, "rooms", {:room_updated, started_room})

          {:noreply,
           socket
           |> put_flash(:info, "¡Partida iniciada!")
           |> push_navigate(to: ~p"/rooms/#{started_room.id}")}

        {:error, :insufficient_players} ->
          {:noreply, put_flash(socket, :error, "Se necesitan al menos 2 jugadores para iniciar")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "No se pudo iniciar la partida")}
      end
    else
      {:noreply, put_flash(socket, :error, "Solo el creador puede iniciar la partida")}
    end
  end

  defp room_type_text("public"), do: "Pública"
  defp room_type_text("private"), do: "Privada"

  defp room_status_text("pending"), do: "Esperando"
  defp room_status_text("started"), do: "En juego"
  defp room_status_text("finished"), do: "Terminada"

  defp room_status_badge_class("pending"), do: "badge-warning"
  defp room_status_badge_class("started"), do: "badge-success"
  defp room_status_badge_class("finished"), do: "badge-neutral"

  defp user_position_in_room(room, user_id) do
    case Enum.find(room.room_users, &(&1.user_id == user_id)) do
      nil -> nil
      room_user -> room_user.position
    end
  end

  defp is_room_creator?(room, user_id), do: room.creator_id == user_id
  defp can_start_room?(room), do: Game.Room.can_start?(room)
end
