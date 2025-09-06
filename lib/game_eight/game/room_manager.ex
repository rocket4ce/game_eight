defmodule GameEight.Game.RoomManager do
  @moduledoc """
  Proceso para manejar el ciclo de vida automático de las salas de juego.
  Se encarga de iniciar automáticamente las salas que han alcanzado el timeout.
  """

  use GenServer
  require Logger
  alias GameEight.Game

  @check_interval :timer.minutes(1)  # Revisar cada minuto

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_check()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:check_rooms, state) do
    check_and_start_rooms()
    schedule_check()
    {:noreply, state}
  end

  defp schedule_check do
    Process.send_after(self(), :check_rooms, @check_interval)
  end

  defp check_and_start_rooms do
    rooms_to_start = Game.get_rooms_to_auto_start()
    
    Enum.each(rooms_to_start, fn room ->
      case Game.start_room(room) do
        {:ok, started_room} ->
          Logger.info("Auto-started room #{started_room.id} (#{started_room.name})")
          
        {:error, reason} ->
          Logger.warning("Failed to auto-start room #{room.id}: #{inspect(reason)}")
      end
    end)
    
    if length(rooms_to_start) > 0 do
      Logger.info("Auto-started #{length(rooms_to_start)} rooms")
    end
  end
end