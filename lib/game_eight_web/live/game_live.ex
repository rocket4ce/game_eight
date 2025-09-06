defmodule GameEightWeb.GameLive do
  @moduledoc """
  LiveView for the main card game interface.

  Handles real-time game interactions with proper card visibility:
  - Players see only their own hand cards
  - All players see cards played on the table
  - Real-time updates for game state changes
  """

  use GameEightWeb, :live_view

  alias GameEight.Game
  alias GameEight.Game.{GameState, PlayerGameState}
  alias Phoenix.PubSub

  @impl true
  def mount(%{"room_id" => room_id}, _session, socket) do
    if connected?(socket) do
      # Subscribe to game updates for this room
      PubSub.subscribe(GameEight.PubSub, "game:#{room_id}")
    end

    # Get current user (assuming we have authentication)
    current_user = socket.assigns[:current_user]

    case load_game_data(room_id, current_user) do
      {:ok, assigns} ->
        socket =
          socket
          |> assign(assigns)
          |> assign(:room_id, room_id)
          |> assign(:selected_cards, [])
          |> assign(:error_message, nil)

        {:ok, socket}

      {:error, _reason} ->
        {:ok, push_navigate(socket, to: ~p"/rooms")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-green-800 text-white">
      <div class="container mx-auto px-4 py-6">
        <!-- Game Header -->
        <div class="mb-6">
          <div class="flex justify-between items-center">
            <h1 class="text-3xl font-bold">Juego de Cartas - Mesa <%= @room_id %></h1>
            <div class="text-lg">
              <span class="font-semibold">Turno:</span>
              <%= if @game_state.status == "playing", do: get_current_player_name(@game_state, @players), else: @game_state.status %>
            </div>
          </div>
        </div>

        <%= if @error_message do %>
          <div class="bg-red-600 text-white p-4 rounded mb-4">
            <%= @error_message %>
          </div>
        <% end %>

        <!-- Game Status and Controls -->
        <div class="mb-6">
          <%= render_game_status(assigns) %>
        </div>

        <!-- Other Players (showing card backs only) -->
        <div class="mb-6">
          <h3 class="text-xl font-semibold mb-3">Otros Jugadores</h3>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <%= for {player, user} <- @other_players do %>
              <div class="bg-green-700 p-4 rounded-lg">
                <div class="flex justify-between items-center mb-2">
                  <span class="font-semibold"><%= user.email %></span>
                  <span class="text-sm bg-blue-600 px-2 py-1 rounded">
                    <%= player.player_status %>
                  </span>
                </div>
                <div class="flex items-center gap-2">
                  <span class="text-sm">Cartas: <%= get_hand_size(player) %></span>
                  <div class="flex gap-1">
                    <%= for _i <- 1..get_hand_size(player) do %>
                      <div class="w-8 h-12 bg-blue-900 border border-blue-700 rounded-sm"></div>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Table Cards (visible to all players) -->
        <div class="mb-6">
          <h3 class="text-xl font-semibold mb-3">Cartas en la Mesa</h3>
          <div class="bg-green-700 p-4 rounded-lg min-h-[200px]">
            <%= if @table_combinations == [] do %>
              <div class="text-center text-gray-300 py-8">
                No hay combinaciones en la mesa aún
              </div>
            <% else %>
              <div class="grid gap-4">
                <%= for {combination, index} <- Enum.with_index(@table_combinations) do %>
                  <div class="bg-green-600 p-3 rounded">
                    <div class="text-sm mb-2">Combinación <%= index + 1 %></div>
                    <div class="flex flex-wrap gap-1">
                      <%= for card <- combination.cards do %>
                        <div class={["game-card", "game-card-#{card.deck}", card_type_class(card.type)]}>
                          <span class="card-value"><%= card.card %></span>
                          <span class="card-suit"><%= card_symbol(card.type) %></span>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Current Player's Hand (only visible to them) -->
        <div class="mb-6">
          <h3 class="text-xl font-semibold mb-3">Tus Cartas</h3>
          <div class="bg-green-700 p-4 rounded-lg">
            <%= if @current_player_hand == [] do %>
              <div class="text-center text-gray-300 py-8">
                No tienes cartas en la mano
              </div>
            <% else %>
              <div class="flex flex-wrap gap-2">
                <%= for card <- @current_player_hand do %>
                  <button
                    phx-click="toggle_card_selection"
                    phx-value-position={card.position}
                    class={[
                      "game-card",
                      "game-card-#{card.deck}",
                      card_type_class(card.type),
                      if(card.position in @selected_cards, do: "selected", else: "")
                    ]}
                  >
                    <span class="card-value"><%= card.card %></span>
                    <span class="card-suit"><%= card_symbol(card.type) %></span>
                  </button>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Game Actions -->
        <%= if @is_current_player and @game_state.status == "playing" do %>
          <div class="bg-gray-800 p-4 rounded-lg">
            <h4 class="text-lg font-semibold mb-3">Acciones de Juego</h4>
            <div class="flex gap-3">
              <button
                phx-click="play_combination"
                phx-value-type="trio"
                disabled={length(@selected_cards) < 3}
                class="bg-blue-600 hover:bg-blue-700 disabled:bg-gray-600 px-4 py-2 rounded"
              >
                Jugar Trío (<%= length(@selected_cards) %> seleccionadas)
              </button>

              <button
                phx-click="play_combination"
                phx-value-type="sequence"
                disabled={length(@selected_cards) < 4}
                class="bg-purple-600 hover:bg-purple-700 disabled:bg-gray-600 px-4 py-2 rounded"
              >
                Jugar Secuencia (<%= length(@selected_cards) %> seleccionadas)
              </button>

              <button
                phx-click="draw_card"
                class="bg-green-600 hover:bg-green-700 px-4 py-2 rounded"
              >
                Robar Carta
              </button>

              <button
                phx-click="pass_turn"
                class="bg-yellow-600 hover:bg-yellow-700 px-4 py-2 rounded"
              >
                Pasar Turno
              </button>
            </div>
          </div>
        <% end %>

        <!-- Deck and Discard Pile -->
        <div class="mt-6 flex justify-center gap-6">
          <div class="text-center">
            <div class="text-sm mb-2">Mazo</div>
            <div class="w-16 h-24 bg-blue-900 border-2 border-blue-700 rounded flex items-center justify-center">
              <span class="text-xs"><%= @deck_count %></span>
            </div>
          </div>

          <%= if @discard_top_card do %>
            <div class="text-center">
              <div class="text-sm mb-2">Descarte</div>
              <div class={["game-card", "game-card-#{@discard_top_card.deck}", card_type_class(@discard_top_card.type)]}>
                <span class="card-value"><%= @discard_top_card.card %></span>
                <span class="card-suit"><%= card_symbol(@discard_top_card.type) %></span>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions for rendering
  defp render_game_status(assigns) do
    case assigns.game_state.status do
      "dice_rolling" ->
        ~H"""
        <div class="bg-yellow-600 p-4 rounded-lg">
          <h3 class="text-lg font-semibold">¡Tira los dados para determinar el orden!</h3>
          <%= if @can_roll_dice do %>
            <button phx-click="roll_dice" class="mt-2 bg-white text-yellow-600 px-4 py-2 rounded font-semibold">
              Tirar Dados
            </button>
          <% else %>
            <p class="mt-2">Esperando a que otros jugadores tiren los dados...</p>
          <% end %>
        </div>
        """

      "playing" ->
        ~H"""
        <div class="bg-blue-600 p-4 rounded-lg">
          <div class="flex justify-between items-center">
            <div>
              <h3 class="text-lg font-semibold">Juego en Progreso</h3>
              <p>Movimientos realizados: <%= @current_player_moves %> / 5</p>
            </div>
            <div class="text-right">
              <p class="text-sm">Cartas jugadas desde la mano: <%= @cards_from_hand %> / 4</p>
            </div>
          </div>
        </div>
        """

      _ ->
        ~H"""
        <div class="bg-gray-600 p-4 rounded-lg">
          <h3 class="text-lg font-semibold">Estado: <%= String.capitalize(@game_state.status) %></h3>
        </div>
        """
    end
  end

  # Event handlers will be implemented next
  @impl true
  def handle_event("toggle_card_selection", %{"position" => position}, socket) do
    position = String.to_integer(position)
    selected_cards = socket.assigns.selected_cards

    updated_selection =
      if position in selected_cards do
        List.delete(selected_cards, position)
      else
        [position | selected_cards]
      end

    {:noreply, assign(socket, :selected_cards, updated_selection)}
  end

  def handle_event("roll_dice", _params, socket) do
    # TODO: Implement dice rolling
    {:noreply, socket}
  end

  def handle_event("play_combination", %{"type" => _type}, socket) do
    # TODO: Implement combination playing
    {:noreply, socket}
  end

  def handle_event("draw_card", _params, socket) do
    # TODO: Implement card drawing
    {:noreply, socket}
  end

  def handle_event("pass_turn", _params, socket) do
    # TODO: Implement turn passing
    {:noreply, socket}
  end

  # Helper functions
  defp load_game_data(room_id, current_user) do
    with {:ok, _room} <- Game.get_room_with_users(room_id),
         {:ok, game_state} <- get_game_state(room_id),
         {:ok, players} <- get_players_data(game_state),
         {:ok, current_player} <- find_current_player(players, current_user.id) do

      # Separate current player from others
      other_players = Enum.reject(players, fn {player, _user} -> player.user_id == current_user.id end)

      # Get current player's hand (private)
      current_player_hand = PlayerGameState.hand_to_cards(current_player)

      # Get table combinations (public)
      table_combinations = GameState.table_combinations_to_cards(game_state)

      # Get deck information
      deck_cards = GameState.deck_to_cards(game_state)
      deck_count = length(deck_cards)
      discard_top_card = List.first(deck_cards) # Simplified - should be discard pile

      assigns = %{
        game_state: game_state,
        players: players,
        other_players: other_players,
        current_player: current_player,
        current_player_hand: current_player_hand,
        table_combinations: table_combinations,
        deck_count: deck_count,
        discard_top_card: discard_top_card,
        is_current_player: is_current_turn?(game_state, current_user.id),
        can_roll_dice: can_roll_dice?(game_state, current_player),
        current_player_moves: current_player.moves_made_this_turn || 0,
        cards_from_hand: 0 # TODO: Calculate from player state
      }

      {:ok, assigns}
    else
      error -> error
    end
  end

  defp get_game_state(room_id) do
    case Game.get_game_state_by_room(room_id) do
      nil -> {:error, :game_not_found}
      game_state -> {:ok, game_state}
    end
  end

  defp get_players_data(_game_state) do
    # TODO: Implement proper player data loading with users
    {:ok, []}
  end

  defp find_current_player(players, user_id) do
    case Enum.find(players, fn {player, _user} -> player.user_id == user_id end) do
      {player, _user} -> {:ok, player}
      nil -> {:error, :player_not_found}
    end
  end

  defp get_current_player_name(_game_state, _players) do
    # TODO: Implement current player name lookup
    "Jugador Actual"
  end

  defp get_hand_size(player) do
    case player.hand_cards do
      %{"cards" => cards} when is_list(cards) -> length(cards)
      _ -> 0
    end
  end

  defp is_current_turn?(_game_state, _user_id) do
    # TODO: Implement turn checking logic
    false
  end

  defp can_roll_dice?(game_state, player) do
    game_state.status == "dice_rolling" && is_nil(player.dice_roll)
  end

  defp card_type_class(type) do
    case type do
      :hearts -> "suit-hearts"
      :diamonds -> "suit-diamonds"
      :clubs -> "suit-clubs"
      :spades -> "suit-spades"
    end
  end

  defp card_symbol(type) do
    case type do
      :hearts -> "♥"
      :diamonds -> "♦"
      :clubs -> "♣"
      :spades -> "♠"
    end
  end
end
