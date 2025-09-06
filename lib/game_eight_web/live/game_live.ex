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
  alias GameEight.Repo
  alias Phoenix.PubSub

  @impl true
  def mount(%{"room_id" => room_id}, _session, socket) do
    if connected?(socket) do
      # Subscribe to game updates for this room
      PubSub.subscribe(GameEight.PubSub, "game:#{room_id}")
    end

    # Get current user from authenticated session
    current_user = socket.assigns.current_scope.user

    case load_game_data(room_id, current_user) do
      {:ok, assigns} ->
        socket =
          socket
          |> assign(assigns)
          |> assign(:room_id, room_id)
          |> assign(:current_user, current_user)
          |> assign(:selected_cards, [])
          |> assign(:selected_table_cards, [])
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
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen bg-green-800 text-white">
        <div class="container mx-auto px-4 py-6">
          <!-- Game Header -->
          <div class="mb-6">
            <div class="flex justify-between items-center">
              <h1 class="text-3xl font-bold">Juego de Cartas - Mesa {@room_id}</h1>
              <div class="text-lg">
                <span class="font-semibold">Turno:</span>
                {if @game_state.status == "playing",
                  do: get_current_player_name(@game_state, @players),
                  else: @game_state.status}
              </div>
            </div>
          </div>

          <%= if @error_message do %>
            <div class="bg-red-600 text-white p-4 rounded mb-4">
              {@error_message}
            </div>
          <% end %>
          
    <!-- Game Status and Controls -->
          <div class="mb-6">
            {render_game_status(assigns)}
          </div>
          
    <!-- Other Players (showing card backs only) -->
          <div class="mb-6">
            <h3 class="text-xl font-semibold mb-3">Otros Jugadores</h3>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              <%= for {player, user} <- @other_players do %>
                <div class="bg-green-700 p-4 rounded-lg">
                  <div class="flex justify-between items-center mb-2">
                    <span class="font-semibold">{user.email}</span>
                    <span class="text-sm bg-blue-600 px-2 py-1 rounded">
                      {player.player_status}
                    </span>
                  </div>
                  <div class="flex items-center gap-2">
                    <span class="text-sm">Cartas: {get_hand_size(player)}</span>
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
              <%= if @table_combinations == %{} do %>
                <div class="text-center text-gray-300 py-8">
                  No hay combinaciones en la mesa aún
                </div>
              <% else %>
                <div class="grid gap-4">
                  <%= for {{combination_name, cards}, index} <- Enum.with_index(@table_combinations) do %>
                    <div
                      id={"combination-drop-zone-#{combination_name}"}
                      phx-hook="CardDropZone"
                      data-drop-zone="add-to-combination"
                      data-combination-name={combination_name}
                      data-is-current-turn={
                        to_string(@is_current_player and @game_state.status == "playing")
                      }
                      class={[
                        "bg-green-600 p-3 rounded",
                        "combination-container",
                        if(
                          @is_current_player and @game_state.status == "playing" and
                            length(cards) > 3,
                          do: "can-take-card",
                          else: "cannot-take-card"
                        )
                      ]}
                    >
                      <div class="flex justify-between items-center mb-2">
                        <div class="text-sm">
                          Combinación {index + 1} ({combination_name})
                          <%= if @is_current_player and @game_state.status == "playing" do %>
                            <span class={[
                              "text-xs ml-2 px-2 py-1 rounded",
                              if(length(cards) > 3,
                                do: "bg-green-500 text-white",
                                else: "bg-red-500 text-white"
                              )
                            ]}>
                              {if length(cards) > 3, do: "Puedes tomar", else: "Mínimo requerido"}
                            </span>
                          <% end %>
                        </div>
                        <%= if @is_current_player and @game_state.status == "playing" and total_selected_cards(assigns) > 0 do %>
                          <button
                            phx-click="play_combination"
                            phx-value-type="add_to_combination"
                            phx-value-target={combination_name}
                            disabled={total_selected_cards(assigns) == 0}
                            class="bg-yellow-600 hover:bg-yellow-700 disabled:bg-gray-600 px-2 py-1 text-xs rounded"
                          >
                            + Agregar ({total_selected_cards(assigns)})
                          </button>
                        <% end %>
                      </div>
                      <div class="flex flex-wrap gap-1">
                        <%= for {card, index} <- Enum.with_index(cards) do %>
                          <div
                            id={"table-card-#{combination_name}-#{index}"}
                            phx-click={
                              if @is_current_player and @game_state.status == "playing" and
                                   length(cards) > 3,
                                 do: "toggle_table_card_selection"
                            }
                            phx-value-combination={combination_name}
                            phx-value-position={index}
                            phx-value-card-id={"#{combination_name}-#{index}"}
                            class={[
                              "game-card cursor-pointer select-none relative",
                              "deck-" <> to_string(card.deck),
                              card_type_class(card.type),
                              if("#{combination_name}-#{index}" in @selected_table_cards,
                                do: "selected table-selected",
                                else: ""
                              ),
                              if(length(cards) <= 3, do: "opacity-50 cursor-not-allowed", else: "")
                            ]}
                            phx-hook="CardDragSource"
                            data-position={index}
                            data-source="table"
                            data-combination-name={combination_name}
                            data-card-value={card.card}
                            data-card-type={card.type}
                            data-deck={card.deck}
                          >
                            <%= if "#{combination_name}-#{index}" in @selected_table_cards do %>
                              <div class="absolute -top-1 -right-1 w-4 h-4 bg-orange-500 rounded-full flex items-center justify-center">
                                <span class="text-white text-xs">📋</span>
                              </div>
                            <% end %>
                            <span class="card-value">{card.card}</span>
                            <span class="card-suit">{card_symbol(card.type)}</span>
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
            <div
              class="bg-green-700 p-4 rounded-lg"
              id="player-hand-area"
              phx-hook="CardDropZone"
              data-drop-zone="hand"
            >
              <%= if @current_player_hand == [] do %>
                <div class="text-center text-gray-300 py-8">
                  No tienes cartas en la mano
                </div>
              <% else %>
                <div class="flex flex-wrap gap-2" id="hand-cards-container">
                  <%= for {card, index} <- Enum.with_index(@current_player_hand) do %>
                    <!-- Drop zone before each card for reordering -->
                    <div
                      class="hand-drop-zone"
                      id={"hand-drop-#{index}"}
                      phx-hook="CardDropZone"
                      data-drop-zone="hand-reorder"
                      data-position={index}
                    >
                    </div>

                    <div
                      id={"hand-card-#{card.position}"}
                      draggable="true"
                      phx-click="toggle_card_selection"
                      phx-value-position={card.position}
                      phx-hook="CardDragSource"
                      data-position={card.position}
                      data-source="hand"
                      data-card-value={card.card}
                      data-card-type={card.type}
                      class={[
                        "game-card cursor-pointer select-none relative",
                        "deck-#{card.deck}",
                        card_type_class(card.type),
                        if(card.position in @selected_cards, do: "selected hand-selected", else: "")
                      ]}
                    >
                      <%= if card.position in @selected_cards do %>
                        <div class="absolute -top-1 -right-1 w-4 h-4 bg-green-500 rounded-full flex items-center justify-center">
                          <span class="text-white text-xs">✓</span>
                        </div>
                      <% end %>
                      <span class="card-value">{card.card}</span>
                      <span class="card-suit">{card_symbol(card.type)}</span>
                    </div>
                  <% end %>
                  
    <!-- Final drop zone after last card -->
                  <div
                    class="hand-drop-zone"
                    id={"hand-drop-#{length(@current_player_hand)}"}
                    phx-hook="CardDropZone"
                    data-drop-zone="hand-reorder"
                    data-position={length(@current_player_hand)}
                  >
                  </div>
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
                  disabled={total_selected_cards(assigns) < 3}
                  class={[
                    "px-4 py-2 rounded transition-colors",
                    if(total_selected_cards(assigns) >= 3,
                      do: "bg-blue-600 hover:bg-blue-700 text-white",
                      else: "bg-gray-600 text-gray-400 cursor-not-allowed"
                    )
                  ]}
                >
                  🃏 Jugar Trío ({total_selected_cards(assigns)} cartas)
                  <%= if length(@selected_table_cards) > 0 do %>
                    <span class="text-yellow-300">*</span>
                  <% end %>
                </button>

                <button
                  phx-click="play_combination"
                  phx-value-type="sequence"
                  disabled={total_selected_cards(assigns) < 3}
                  class={[
                    "px-4 py-2 rounded transition-colors",
                    if(total_selected_cards(assigns) >= 3,
                      do: "bg-purple-600 hover:bg-purple-700 text-white",
                      else: "bg-gray-600 text-gray-400 cursor-not-allowed"
                    )
                  ]}
                >
                  📊 Jugar Escalera ({total_selected_cards(assigns)} cartas)
                  <%= if length(@selected_table_cards) > 0 do %>
                    <span class="text-yellow-300">*</span>
                  <% end %>
                </button>

                <button
                  phx-click="draw_card"
                  class="bg-green-600 hover:bg-green-700 px-4 py-2 rounded text-white transition-colors"
                >
                  🃟 Robar Carta
                </button>

                <button
                  phx-click="pass_turn"
                  class="bg-yellow-600 hover:bg-yellow-700 px-4 py-2 rounded text-white transition-colors"
                >
                  ⏭️ Pasar Turno
                </button>
              </div>
              
    <!-- Leyenda para cartas mixtas -->
              <%= if length(@selected_table_cards) > 0 do %>
                <div class="mt-2 text-xs text-yellow-300">
                  <span class="text-yellow-300">*</span> Incluye cartas de la mesa - Combinación mixta
                </div>
              <% end %>
            </div>
            
    <!-- Instrucciones para Combinaciones Mixtas -->
            <%= if @is_current_player and @game_state.status == "playing" do %>
              <div class="mt-4 bg-blue-900 p-3 rounded-lg border border-blue-700">
                <h5 class="text-sm font-semibold mb-2 text-blue-200">💡 Instrucciones de Juego</h5>
                <div class="text-xs text-blue-300 space-y-1">
                  <p>
                    <strong>Combinaciones Mixtas:</strong>
                    Puedes combinar cartas de tu mano con cartas de las combinaciones de la mesa.
                  </p>

                  <div class="grid grid-cols-1 md:grid-cols-2 gap-2 mt-2">
                    <div>
                      <p class="text-blue-200 font-medium">🖱️ Cómo seleccionar:</p>
                      <ul class="list-disc list-inside ml-2 space-y-0.5">
                        <li>Haz clic en cartas de tu mano</li>
                        <li>Haz clic en cartas de combinaciones con 4+ cartas</li>
                        <li>Las cartas seleccionadas se marcan con borde</li>
                      </ul>
                    </div>

                    <div>
                      <p class="text-blue-200 font-medium">🎯 Acciones disponibles:</p>
                      <ul class="list-disc list-inside ml-2 space-y-0.5">
                        <li><strong>Trío:</strong> 3+ cartas del mismo valor</li>
                        <li><strong>Escalera:</strong> 3+ cartas consecutivas (mismo palo)</li>
                        <li><strong>Agregar:</strong> A combinación existente</li>
                      </ul>
                    </div>
                  </div>

                  <div class="mt-2 p-2 bg-blue-800 rounded">
                    <p class="text-yellow-300 font-medium">
                      📊 Cartas seleccionadas:
                      <span class="font-bold">{total_selected_cards(assigns)}</span>
                      (<span class="text-green-300"><%= length(@selected_cards) %> de la mano</span> + <span class="text-orange-300"><%= length(@selected_table_cards) %> de la mesa</span>)
                    </p>

                    <%= if length(@selected_cards) > 0 and length(@selected_table_cards) > 0 do %>
                      <p class="text-yellow-200 text-xs mt-1">
                        ⚡ ¡Combinación mixta activa! Las cartas de la mesa se añadirán a tu combinación.
                      </p>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          <% end %>
          
    <!-- Deck and Discard Pile -->
          <div class="mt-6 flex justify-center gap-6">
            <div class="text-center">
              <div class="text-sm mb-2">Mazo</div>
              <div class="w-16 h-24 bg-blue-900 border-2 border-blue-700 rounded flex items-center justify-center">
                <span class="text-xs">{@deck_count}</span>
              </div>
            </div>

            <%= if @discard_top_card do %>
              <div class="text-center">
                <div class="text-sm mb-2">Descarte</div>
                <div class={[
                  "game-card",
                  "deck-#{@discard_top_card.deck}",
                  card_type_class(@discard_top_card.type)
                ]}>
                  <span class="card-value">{@discard_top_card.card}</span>
                  <span class="card-suit">{card_symbol(@discard_top_card.type)}</span>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
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
            <button
              phx-click="roll_dice"
              class="mt-2 bg-white text-yellow-600 px-4 py-2 rounded font-semibold"
            >
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
              <p>Movimientos realizados: {@current_player_moves} / 5</p>
            </div>
            <div class="text-right">
              <p class="text-sm">Cartas jugadas desde la mano: {@cards_from_hand} / 4</p>
            </div>
          </div>
        </div>
        """

      _ ->
        ~H"""
        <div class="bg-gray-600 p-4 rounded-lg">
          <h3 class="text-lg font-semibold">Estado: {String.capitalize(@game_state.status)}</h3>
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

  def handle_event(
        "toggle_table_card_selection",
        %{"combination" => combination_name, "position" => _position, "card-id" => card_id},
        socket
      ) do
    # Only allow current player to select table cards during their turn
    unless socket.assigns.is_current_player and socket.assigns.game_state.status == "playing" do
      {:noreply, socket}
    else
      selected_table_cards = socket.assigns.selected_table_cards

      # Validate that taking this card would still leave at least 3 cards in the combination
      table_combinations = socket.assigns.game_state.table_combinations
      combination_cards = Map.get(table_combinations, combination_name, [])

      if length(combination_cards) <= 3 do
        # Can't select cards from combinations with only 3 cards
        {:noreply,
         put_flash(socket, :error, "No puedes tomar cartas de una combinación con solo 3 cartas.")}
      else
        updated_selection =
          if card_id in selected_table_cards do
            List.delete(selected_table_cards, card_id)
          else
            [card_id | selected_table_cards]
          end

        {:noreply, assign(socket, :selected_table_cards, updated_selection)}
      end
    end
  end

  def handle_event("roll_dice", _params, socket) do
    game_state = socket.assigns.game_state
    user_id = socket.assigns.current_user.id

    # Generate random dice value (1-6)
    dice_value = Enum.random(1..6)

    case GameEight.Game.Engine.roll_dice(game_state.id, user_id, dice_value) do
      {:ok, updated_game_state} ->
        # Update socket with new game state
        updated_socket = update_game_state(socket, updated_game_state)

        # Broadcast to other players
        PubSub.broadcast(
          GameEight.PubSub,
          "game:#{socket.assigns.room_id}",
          {:dice_rolled,
           %{user_id: user_id, dice_value: dice_value, game_state: updated_game_state}}
        )

        {:noreply, updated_socket}

      {:error, reason} ->
        error_message = format_error_message(reason)
        {:noreply, assign(socket, :error_message, error_message)}
    end
  end

  def handle_event("play_combination", %{"type" => combination_type} = params, socket) do
    game_state = socket.assigns.game_state
    user_id = socket.assigns.current_user.id
    selected_hand_positions = socket.assigns.selected_cards
    selected_table_cards = socket.assigns.selected_table_cards

    # Get the selected cards from player's hand
    hand_cards = socket.assigns.current_player_hand

    selected_hand_cards =
      Enum.filter(hand_cards, fn card ->
        card.position in selected_hand_positions
      end)

    # Get the selected cards from table combinations
    selected_table_card_data =
      selected_table_cards
      |> Enum.map(fn card_id ->
        [combination_name, index_str] = String.split(card_id, "-", parts: 2)
        index = String.to_integer(index_str)

        # Find the card in the table combination by index
        table_combinations = socket.assigns.table_combinations
        combination_cards = Map.get(table_combinations, combination_name, [])

        card = Enum.at(combination_cards, index)

        if card do
          {combination_name, card}
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    # Get target combination if it's an "add_to_combination" action
    target_combination = Map.get(params, "target")

    # Use mixed card play if we have table cards, otherwise use regular play
    result =
      if selected_table_card_data == [] do
        # Regular play with only hand cards
        GameEight.Game.Engine.play_cards(
          game_state.id,
          user_id,
          selected_hand_cards,
          combination_type,
          target_combination
        )
      else
        # Mixed play with both hand and table cards
        GameEight.Game.Engine.play_mixed_cards(
          game_state.id,
          user_id,
          selected_hand_cards,
          selected_table_card_data,
          combination_type,
          target_combination
        )
      end

    case result do
      {:ok, updated_game_state, _updated_player} ->
        updated_socket =
          socket
          |> update_game_state(updated_game_state)
          |> assign(:selected_cards, [])
          |> assign(:selected_table_cards, [])
          |> assign(:error_message, nil)

        # Broadcast to other players
        all_selected_cards =
          selected_hand_cards ++ Enum.map(selected_table_card_data, fn {_, card} -> card end)

        PubSub.broadcast(
          GameEight.PubSub,
          "game:#{socket.assigns.room_id}",
          {:cards_played, %{user_id: user_id, cards: all_selected_cards, type: combination_type}}
        )

        {:noreply, updated_socket}

      {:error, reason} ->
        error_message = format_error_message(reason)
        {:noreply, assign(socket, :error_message, error_message)}
    end
  end

  def handle_event("draw_card", _params, socket) do
    game_state = socket.assigns.game_state
    user_id = socket.assigns.current_user.id

    case GameEight.Game.Engine.draw_card(game_state.id, user_id) do
      {:ok, updated_game_state} ->
        updated_socket =
          socket
          |> update_game_state(updated_game_state)
          |> assign(:error_message, nil)

        # Broadcast to other players
        PubSub.broadcast(
          GameEight.PubSub,
          "game:#{socket.assigns.room_id}",
          {:card_drawn, %{user_id: user_id}}
        )

        {:noreply, updated_socket}

      {:error, reason} ->
        error_message = format_error_message(reason)
        {:noreply, assign(socket, :error_message, error_message)}
    end
  end

  def handle_event("pass_turn", _params, socket) do
    game_state = socket.assigns.game_state
    user_id = socket.assigns.current_user.id

    case GameEight.Game.Engine.pass_turn(game_state.id, user_id) do
      {:ok, updated_game_state} ->
        updated_socket =
          socket
          |> update_game_state(updated_game_state)
          |> assign(:selected_cards, [])
          |> assign(:selected_table_cards, [])
          |> assign(:error_message, nil)

        # Broadcast to other players
        PubSub.broadcast(
          GameEight.PubSub,
          "game:#{socket.assigns.room_id}",
          {:turn_passed, %{user_id: user_id}}
        )

        {:noreply, updated_socket}

      {:error, reason} ->
        error_message = format_error_message(reason)
        {:noreply, assign(socket, :error_message, error_message)}
    end
  end

  def handle_event(
        "reorder_hand_card",
        %{"from_position" => from_pos_str, "to_position" => to_pos_str},
        socket
      ) do
    from_position = String.to_integer(from_pos_str)
    to_position = String.to_integer(to_pos_str)
    game_state = socket.assigns.game_state
    user_id = socket.assigns.current_user.id

    case GameEight.Game.Engine.reorder_hand_cards(
           game_state.id,
           user_id,
           from_position,
           to_position
         ) do
      {:ok, updated_game_state} ->
        updated_socket =
          socket
          |> update_game_state(updated_game_state)
          |> assign(:error_message, nil)

        {:noreply, updated_socket}

      {:error, reason} ->
        error_message = format_error_message(reason)
        {:noreply, assign(socket, :error_message, error_message)}
    end
  end

  def handle_event(
        "take_table_card",
        %{"combination_name" => combination_name, "card_position" => card_position},
        socket
      ) do
    game_state = socket.assigns.game_state
    user_id = socket.assigns.current_user.id

    case GameEight.Game.Engine.take_table_card(
           game_state.id,
           user_id,
           combination_name,
           card_position
         ) do
      {:ok, updated_game_state} ->
        updated_socket =
          socket
          |> update_game_state(updated_game_state)
          |> assign(:error_message, nil)

        # Broadcast to other players
        PubSub.broadcast(
          GameEight.PubSub,
          "game:#{socket.assigns.room_id}",
          {:card_taken,
           %{user_id: user_id, combination_name: combination_name, card_position: card_position}}
        )

        {:noreply, updated_socket}

      {:error, reason} ->
        error_message = format_error_message(reason)
        {:noreply, assign(socket, :error_message, error_message)}
    end
  end

  def handle_event(
        "add_cards_to_combination",
        %{"combination_name" => combination_name, "card_positions" => card_positions},
        socket
      ) do
    IO.puts("=== ADD CARDS TO COMBINATION EVENT ===")
    IO.puts("Combination name: #{combination_name}")
    IO.puts("Card positions: #{inspect(card_positions)}")

    game_state = socket.assigns.game_state
    user_id = socket.assigns.current_user.id

    # Get the selected cards from player's hand
    hand_cards = socket.assigns.current_player_hand
    positions = if is_list(card_positions), do: card_positions, else: [card_positions]

    IO.puts("Hand cards: #{inspect(Enum.map(hand_cards, &{&1.position, &1.card, &1.type}))}")
    IO.puts("Looking for positions: #{inspect(positions)}")

    selected_cards =
      Enum.filter(hand_cards, fn card ->
        to_string(card.position) in positions
      end)

    IO.puts(
      "Selected cards: #{inspect(Enum.map(selected_cards, &{&1.position, &1.card, &1.type}))}"
    )

    case GameEight.Game.Engine.play_cards(
           game_state.id,
           user_id,
           selected_cards,
           "add_to_combination",
           combination_name
         ) do
      {:ok, updated_game_state, _updated_player} ->
        IO.puts("SUCCESS: Cards added to combination")

        updated_socket =
          socket
          |> update_game_state(updated_game_state)
          |> assign(:selected_cards, [])
          |> assign(:error_message, nil)

        # Broadcast to other players
        PubSub.broadcast(
          GameEight.PubSub,
          "game:#{socket.assigns.room_id}",
          {:cards_played,
           %{
             user_id: user_id,
             cards: selected_cards,
             type: "add_to_combination",
             target: combination_name
           }}
        )

        {:noreply, updated_socket}

      {:error, reason} ->
        IO.puts("ERROR: #{inspect(reason)}")
        error_message = format_error_message(reason)
        {:noreply, assign(socket, :error_message, error_message)}
    end
  end

  def handle_event(
        "move_card_between_combinations",
        %{
          "source_combination" => source_combination,
          "target_combination" => target_combination,
          "card_id" => card_id
        },
        socket
      ) do
    IO.puts("=== MOVE CARD BETWEEN COMBINATIONS EVENT ===")
    IO.puts("Source combination: #{source_combination}")
    IO.puts("Target combination: #{target_combination}")
    IO.puts("Card ID: #{card_id}")

    game_state = socket.assigns.game_state
    user_id = socket.assigns.current_user.id

    # Find the card in the source combination
    case find_card_in_combination(game_state, source_combination, card_id) do
      {:ok, card} ->
        case GameEight.Game.Engine.move_card_between_combinations(
               game_state.id,
               user_id,
               source_combination,
               target_combination,
               card
             ) do
          {:ok, updated_game_state, _updated_player} ->
            IO.puts("SUCCESS: Card moved between combinations")

            updated_socket =
              socket
              |> update_game_state(updated_game_state)
              |> assign(:selected_table_cards, [])
              |> assign(:error_message, nil)

            # Broadcast to other players
            PubSub.broadcast(
              GameEight.PubSub,
              "game:#{socket.assigns.room_id}",
              {:card_moved,
               %{
                 user_id: user_id,
                 source: source_combination,
                 target: target_combination,
                 card: card
               }}
            )

            {:noreply, updated_socket}

          {:error, reason} ->
            IO.puts("ERROR: #{inspect(reason)}")
            error_message = format_error_message(reason)
            {:noreply, assign(socket, :error_message, error_message)}
        end

      {:error, reason} ->
        IO.puts("ERROR: #{inspect(reason)}")
        error_message = format_error_message(reason)
        {:noreply, assign(socket, :error_message, error_message)}
    end
  end

  # PubSub message handlers
  @impl true
  def handle_info(
        {:dice_rolled, %{user_id: _user_id, dice_value: _dice_value, game_state: _game_state}},
        socket
      ) do
    # Refresh game state when another player rolls dice
    updated_socket = update_game_state(socket, socket.assigns.game_state)
    {:noreply, updated_socket}
  end

  def handle_info({:cards_played, %{user_id: _user_id, cards: _cards, type: _type}}, socket) do
    # Refresh game state when another player plays cards
    updated_socket = update_game_state(socket, socket.assigns.game_state)
    {:noreply, updated_socket}
  end

  def handle_info({:card_drawn, %{user_id: _user_id}}, socket) do
    # Refresh game state when another player draws a card
    updated_socket = update_game_state(socket, socket.assigns.game_state)
    {:noreply, updated_socket}
  end

  def handle_info({:turn_passed, %{user_id: _user_id}}, socket) do
    # Refresh game state when another player passes turn
    updated_socket = update_game_state(socket, socket.assigns.game_state)
    {:noreply, updated_socket}
  end

  def handle_info(
        {:card_taken,
         %{user_id: _user_id, combination_name: _combination_name, card_position: _card_position}},
        socket
      ) do
    # Refresh game state when another player takes a card from table
    updated_socket = update_game_state(socket, socket.assigns.game_state)
    {:noreply, updated_socket}
  end

  def handle_info(
        {:card_moved, %{user_id: _user_id, source: _source, target: _target, card: _card}},
        socket
      ) do
    # Refresh game state when another player moves a card between combinations
    updated_socket = update_game_state(socket, socket.assigns.game_state)
    {:noreply, updated_socket}
  end

  def handle_info({:game_finished, %{winner_id: _winner_id, game_state: _game_state}}, socket) do
    # Handle game finished event
    updated_socket = update_game_state(socket, socket.assigns.game_state)
    {:noreply, updated_socket}
  end

  # Catch-all for other PubSub messages
  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  # Helper functions
  defp load_game_data(room_id, current_user) do
    with {:ok, _room} <- Game.get_room_with_users(room_id),
         {:ok, game_state} <- get_game_state(room_id),
         {:ok, players} <- get_players_data(game_state),
         {:ok, current_player} <- find_current_player(players, current_user.id) do
      # Separate current player from others
      other_players =
        Enum.reject(players, fn {player, _user} -> player.user_id == current_user.id end)

      # Get current player's hand (private)
      current_player_hand = PlayerGameState.hand_to_cards(current_player)

      # Get table combinations (public)
      table_combinations = GameState.table_combinations_to_cards(game_state)

      # Get deck information
      deck_cards = GameState.deck_to_cards(game_state)
      deck_count = length(deck_cards)

      discard_top_card =
        case deck_cards do
          [] -> nil
          [card | _] when not is_nil(card.type) -> card
          _ -> nil
        end

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
        # TODO: Calculate from player state
        cards_from_hand: 0
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

  defp get_players_data(game_state) do
    case game_state do
      %GameEight.Game.GameState{} ->
        players =
          game_state
          |> Repo.preload(player_game_states: :user)
          |> Map.get(:player_game_states, [])
          |> Enum.map(fn player_state ->
            {player_state, player_state.user}
          end)

        {:ok, players}

      _ ->
        {:error, :invalid_game_state}
    end
  end

  defp find_current_player(players, user_id) do
    case Enum.find(players, fn {player, _user} -> player.user_id == user_id end) do
      {player, _user} -> {:ok, player}
      nil -> {:error, :player_not_found}
    end
  end

  defp get_current_player_name(game_state, players) do
    current_index = game_state.current_player_index

    case Enum.find(players, fn {player, _user} ->
           player.player_index == current_index
         end) do
      {_player, user} -> user.email
      nil -> "Jugador #{current_index + 1}"
    end
  end

  defp get_hand_size(player) do
    case player.hand_cards do
      %{"cards" => cards} when is_list(cards) -> length(cards)
      _ -> 0
    end
  end

  defp is_current_turn?(game_state, user_id) do
    current_index = game_state.current_player_index

    case game_state.turn_order do
      order when is_list(order) and length(order) > current_index ->
        Enum.at(order, current_index) == user_id

      _ ->
        false
    end
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
      # Handle nil and any other unexpected values
      _ -> "suit-unknown"
    end
  end

  defp card_symbol(type) do
    case type do
      :hearts -> "♥"
      :diamonds -> "♦"
      :clubs -> "♣"
      :spades -> "♠"
      nil -> "?"
      _ -> "?"
    end
  end

  # Helper functions for LiveView updates
  defp update_game_state(socket, _game_state) do
    current_user = socket.assigns.current_user

    case load_game_data(socket.assigns.room_id, current_user) do
      {:ok, assigns} ->
        assign(socket, assigns)

      {:error, _reason} ->
        assign(socket, :error_message, "Error actualizando el estado del juego")
    end
  end

  defp format_error_message(reason) do
    case reason do
      :game_not_found ->
        "Juego no encontrado"

      :not_players_turn ->
        "No es tu turno"

      :invalid_dice_phase ->
        "No puedes tirar dados en este momento"

      :already_rolled_dice ->
        "Ya has tirado los dados"

      :invalid_cards ->
        "Cartas inválidas seleccionadas"

      :insufficient_cards ->
        "Necesitas seleccionar más cartas"

      :invalid_combination ->
        "Combinación inválida"

      :no_moves_left ->
        "No tienes movimientos restantes"

      :too_many_cards_played ->
        "Has alcanzado el límite de 4 cartas por turno. Termina tu turno o roba una carta"

      :combination_not_found ->
        "Combinación no encontrada en la mesa"

      :card_not_found_in_combination ->
        "Carta no encontrada en la combinación"

      :invalid_trio ->
        "Las cartas seleccionadas no forman un trío válido (mismo valor)"

      :invalid_sequence ->
        "Las cartas seleccionadas no forman una escalera válida (mismo palo, consecutivas)"

      :invalid_addition ->
        "No puedes agregar estas cartas a la combinación seleccionada"

      :cards_not_in_hand ->
        "Algunas cartas seleccionadas no están en tu mano"

      {:would_break_minimum_cards, combination_name, remaining} ->
        "No puedes tomar esa carta: la combinación '#{combination_name}' quedaría con #{remaining} cartas (mínimo 3)"

      {:would_break_valid_combination, combination_name, remaining} ->
        "No puedes tomar esa carta: la combinación '#{combination_name}' ya no sería válida con #{remaining} cartas"

      :game_not_in_playing_state ->
        "El juego no está en estado de juego activo"

      :card_not_found ->
        "Carta no encontrada"

      _ ->
        "Error desconocido: #{inspect(reason)}"
    end
  end

  # Helper function to get total selected cards count
  defp total_selected_cards(assigns) do
    length(assigns.selected_cards) + length(assigns.selected_table_cards)
  end

  # Helper function to find a card in a specific combination by card_id
  defp find_card_in_combination(game_state, combination_name, card_id) do
    case Map.get(game_state.table_combinations, combination_name) do
      nil ->
        {:error, :combination_not_found}

      combination_cards ->
        case Enum.find(combination_cards, fn card ->
               "#{card.card}_#{card.type}_#{card.deck}" == card_id
             end) do
          nil ->
            {:error, :card_not_found_in_combination}

          card ->
            {:ok, card}
        end
    end
  end
end
