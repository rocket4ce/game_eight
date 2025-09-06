defmodule GameEight.Game.Engine do
  @moduledoc """
  Core game engine for the card game.

  This module handles all the game logic including:
  - Game initialization and setup
  - Turn management and validation
  - Card playing and combination validation
  - Win condition checking
  - Game state transitions
  """

  alias GameEight.Game.{Card, GameState, PlayerGameState}
  alias GameEight.{Game, Repo}

  @doc """
  Initializes a new game for the given room.
  Creates GameState and PlayerGameState records for all room users.
  """
  def initialize_game(room_id) do
    with {:ok, room} <- Game.get_room_with_users(room_id),
         :ok <- validate_room_for_game(room),
         {:ok, game_state} <- create_game_state(room),
         {:ok, _player_states} <- create_player_states(game_state, room.users),
         {:ok, dice_game_state} <- start_dice_phase(game_state.id) do
      {:ok, dice_game_state}
    end
  end

  @doc """
  Starts the dice rolling phase for turn order determination.
  """
  def start_dice_phase(game_state_id) do
    game_state = Repo.get!(GameState, game_state_id)

    GameState.status_changeset(game_state, %{status: "dice_rolling"})
    |> Repo.update()
  end

  @doc """
  Records a player's dice roll and checks if all players have rolled.
  If so, determines turn order and starts the game.
  """
  def roll_dice(game_state_id, user_id, dice_value)
      when dice_value >= 1 and dice_value <= 6 do
    with {:ok, game_state} <- get_game_state_with_players(game_state_id),
         {:ok, player_state} <- find_player_state(game_state, user_id),
         {:ok, _updated_player} <- update_dice_roll(player_state, dice_value),
         {:ok, updated_game} <- update_dice_results(game_state, user_id, dice_value) do

      if all_players_rolled?(updated_game) do
        start_game_play(updated_game)
      else
        {:ok, updated_game}
      end
    end
  end

  @doc """
  Starts the actual card playing phase after all dice are rolled.
  Deals cards, determines turn order, and sets up initial game state.
  """
  def start_game_play(game_state) do
    with {:ok, deck} <- create_and_shuffle_deck(),
         {:ok, hands, remaining_deck} <- deal_cards_to_players(deck, game_state),
         {:ok, turn_order} <- determine_turn_order(game_state),
         {:ok, _player_updates} <- update_player_hands(game_state, hands),
         {:ok, updated_game} <- update_game_for_play(game_state, remaining_deck, turn_order) do
      {:ok, updated_game}
    end
  end

  @doc """
  Processes a player's move during their turn.
  Validates the move and updates game state accordingly.
  """
  def play_cards(game_state_id, user_id, cards_to_play, combination_type, target_combination \\ nil) do
    with {:ok, game_state} <- get_game_state_with_players(game_state_id),
         :ok <- validate_player_turn(game_state, user_id),
         :ok <- validate_move_limits(game_state),
         {:ok, player_state} <- find_player_state(game_state, user_id),
         {:ok, hand_cards} <- get_player_hand_cards(player_state),
         :ok <- validate_cards_in_hand(hand_cards, cards_to_play),
         :ok <- validate_combination(cards_to_play, combination_type, game_state, target_combination),
         {:ok, updated_player} <- remove_cards_from_hand(player_state, cards_to_play),
         {:ok, updated_game} <- update_table_combinations(game_state, cards_to_play, combination_type, target_combination),
         {:ok, final_game} <- update_move_counts(updated_game),
         {:ok, final_player} <- maybe_activate_player(updated_player) do

      # Check win condition
      if PlayerGameState.has_won?(final_player) do
        finish_game(final_game, user_id)
      else
        {:ok, final_game, final_player}
      end
    end
  end

  @doc """
  Draws a card from the deck for the current player.
  """
  def draw_card(game_state_id, user_id) do
    with {:ok, game_state} <- get_game_state_with_players(game_state_id),
         :ok <- validate_player_turn(game_state, user_id),
         {:ok, player_state} <- find_player_state(game_state, user_id),
         {:ok, deck_cards} <- get_deck_cards(game_state),
         {:ok, drawn_card, remaining_deck} <- draw_from_deck(deck_cards),
         {:ok, _updated_player} <- add_card_to_hand(player_state, drawn_card),
         {:ok, updated_game} <- update_deck(game_state, remaining_deck) do

      # After drawing, player must end turn
      end_turn(updated_game)
    end
  end

  @doc """
  Ends the current player's turn and advances to the next player.
  """
  def end_turn(game_state) do
    next_player_index = get_next_player_index(game_state)

    GameState.turn_changeset(game_state, %{
      current_player_index: next_player_index,
      turn_number: game_state.turn_number + 1,
      moves_left: 5,
      cards_played_this_turn: 0
    })
    |> Repo.update()
  end

  @doc """
  Passes the current player's turn (voluntary pass).
  """
  def pass_turn(game_state_id, user_id) do
    with {:ok, game_state} <- get_game_state_with_players(game_state_id),
         :ok <- validate_player_turn(game_state, user_id) do
      end_turn(game_state)
    end
  end

  # Private helper functions

  defp validate_room_for_game(room) do
    cond do
      room.status != "started" -> {:error, :room_not_started}
      length(room.users) < 2 -> {:error, :insufficient_players}
      length(room.users) > 6 -> {:error, :too_many_players}
      true -> :ok
    end
  end

  defp create_game_state(room) do
    %GameState{}
    |> GameState.changeset(%{
      room_id: room.id,
      max_players: room.max_players,
      cards_per_player: 8,
      status: "initializing"
    })
    |> Repo.insert()
  end

  defp create_player_states(game_state, users) do
    current_time = DateTime.utc_now() |> DateTime.truncate(:second)

    player_states =
      users
      |> Enum.with_index()
      |> Enum.map(fn {user, index} ->
        %{
          id: Ecto.UUID.generate(),
          game_state_id: game_state.id,
          user_id: user.id,
          player_index: index,
          is_ready: true,
          player_status: "player_on",
          hand_cards: %{},
          cards_played_total: 0,
          combinations_made: 0,
          moves_made_this_turn: 0,
          inserted_at: current_time,
          updated_at: current_time
        }
      end)

    {count, _} = Repo.insert_all(PlayerGameState, player_states)
    if count == length(users) do
      {:ok, player_states}
    else
      {:error, :failed_to_create_player_states}
    end
  end

  defp get_game_state_with_players(game_state_id) do
    case Repo.get(GameState, game_state_id) |> Repo.preload([:player_game_states, :users]) do
      nil -> {:error, :game_not_found}
      game_state -> {:ok, game_state}
    end
  end

  defp find_player_state(game_state, user_id) do
    case Enum.find(game_state.player_game_states, &(&1.user_id == user_id)) do
      nil -> {:error, :player_not_found}
      player_state -> {:ok, player_state}
    end
  end

  defp update_dice_roll(player_state, dice_value) do
    PlayerGameState.dice_changeset(player_state, %{dice_roll: dice_value})
    |> Repo.update()
  end

  defp update_dice_results(game_state, user_id, dice_value) do
    dice_results = Map.put(game_state.dice_results, to_string(user_id), dice_value)

    GameState.game_data_changeset(game_state, %{dice_results: dice_results})
    |> Repo.update()
  end

  defp all_players_rolled?(game_state) do
    player_count = length(game_state.player_game_states)
    dice_count = map_size(game_state.dice_results)
    dice_count == player_count
  end

  defp create_and_shuffle_deck do
    deck = Card.create_full_deck() |> Card.shuffle()
    {:ok, deck}
  end

  defp deal_cards_to_players(deck, game_state) do
    player_count = length(game_state.player_game_states)
    cards_per_player = game_state.cards_per_player

    case Card.deal_cards(deck, player_count, cards_per_player) do
      {:error, reason} -> {:error, reason}
      {hands, remaining_deck} -> {:ok, hands, remaining_deck}
    end
  end

  defp determine_turn_order(game_state) do
    turn_order =
      game_state.player_game_states
      |> Enum.map(fn player ->
        dice_value = Map.get(game_state.dice_results, to_string(player.user_id), 0)
        {player.user_id, dice_value, player.player_index}
      end)
      |> Enum.sort_by(fn {_user_id, dice_value, player_index} ->
        {-dice_value, player_index}  # Highest dice first, then by player_index for ties
      end)
      |> Enum.map(fn {user_id, _dice, _index} -> user_id end)

    {:ok, turn_order}
  end

  defp update_player_hands(game_state, hands) do
    results =
      game_state.player_game_states
      |> Enum.with_index()
      |> Enum.map(fn {player_state, index} ->
        hand_cards = Enum.at(hands, index, [])
        hand_data = PlayerGameState.cards_to_hand(hand_cards)

        PlayerGameState.hand_changeset(player_state, %{hand_cards: hand_data})
        |> Repo.update()
      end)

    # Check if all updates were successful
    case Enum.find(results, fn result -> match?({:error, _}, result) end) do
      nil -> {:ok, :updated}
      {:error, reason} -> {:error, reason}
    end
  end

  defp update_game_for_play(game_state, remaining_deck, turn_order) do
    deck_data = GameState.cards_to_deck(remaining_deck)

    GameState.changeset(game_state, %{
      status: "playing",
      deck: deck_data,
      turn_order: turn_order,
      current_player_index: 0,
      moves_left: 5,
      cards_played_this_turn: 0
    })
    |> Repo.update()
  end

  defp validate_player_turn(game_state, user_id) do
    current_player_id = GameState.current_player_id(game_state)

    if current_player_id == user_id do
      :ok
    else
      {:error, :not_your_turn}
    end
  end

  defp validate_move_limits(game_state) do
    cond do
      game_state.moves_left <= 0 -> {:error, :no_moves_left}
      game_state.cards_played_this_turn >= 4 -> {:error, :too_many_cards_played}
      true -> :ok
    end
  end

  defp get_player_hand_cards(player_state) do
    hand_cards = PlayerGameState.hand_to_cards(player_state)
    {:ok, hand_cards}
  end

  defp validate_cards_in_hand(hand_cards, cards_to_play) do
    hand_ids = MapSet.new(hand_cards, &Card.dom_id/1)
    play_ids = MapSet.new(cards_to_play, &Card.dom_id/1)

    if MapSet.subset?(play_ids, hand_ids) do
      :ok
    else
      {:error, :cards_not_in_hand}
    end
  end

  defp validate_combination(cards, "trio", _game_state, nil) do
    if Card.valid_trio?(cards) do
      :ok
    else
      {:error, :invalid_trio}
    end
  end

  defp validate_combination(cards, "sequence", _game_state, nil) do
    if Card.valid_sequence?(cards) do
      :ok
    else
      {:error, :invalid_sequence}
    end
  end

  defp validate_combination(_cards, "add_to_combination", _game_state, _target_combination) do
    # TODO: Implement validation for adding to existing combinations
    # This would check if the cards can be validly added to the target combination
    :ok
  end

  defp remove_cards_from_hand(player_state, cards_to_remove) do
    PlayerGameState.remove_cards_from_hand(player_state, cards_to_remove)
  end

  defp update_table_combinations(game_state, cards, combination_type, target_combination) do
    current_combinations = game_state.table_combinations

    updated_combinations = case combination_type do
      "trio" -> add_new_combination(current_combinations, cards, "trio")
      "sequence" -> add_new_combination(current_combinations, cards, "sequence")
      "add_to_combination" -> add_to_existing_combination(current_combinations, cards, target_combination)
    end

    GameState.game_data_changeset(game_state, %{table_combinations: updated_combinations})
    |> Repo.update()
  end

  defp add_new_combination(combinations, cards, type) do
    # Generate unique key for new combination
    existing_keys = Map.keys(combinations)
    new_key = generate_combination_key(type, existing_keys)

    card_maps = Enum.map(cards, &Map.from_struct/1)
    Map.put(combinations, new_key, card_maps)
  end

  defp add_to_existing_combination(combinations, cards, target_key) do
    case Map.get(combinations, target_key) do
      nil -> combinations  # Target combination doesn't exist
      existing_cards ->
        card_maps = Enum.map(cards, &Map.from_struct/1)
        updated_cards = existing_cards ++ card_maps
        Map.put(combinations, target_key, updated_cards)
    end
  end

  defp generate_combination_key(type, existing_keys) do
    type_keys = Enum.filter(existing_keys, &String.starts_with?(&1, type))
    index = length(type_keys)
    "#{type}_#{index}"
  end

  defp update_move_counts(game_state) do
    GameState.turn_changeset(game_state, %{
      moves_left: game_state.moves_left - 1,
      cards_played_this_turn: game_state.cards_played_this_turn + 1
    })
    |> Repo.update()
  end

  defp maybe_activate_player(player_state) do
    if player_state.player_status == "player_off" do
      PlayerGameState.activate_player(player_state)
    else
      {:ok, player_state}
    end
  end

  defp finish_game(game_state, winner_user_id) do
    GameState.status_changeset(game_state, %{status: "finished"})
    |> Repo.update()
    |> case do
      {:ok, updated_game} -> {:ok, updated_game, winner_user_id}
      error -> error
    end
  end

  defp get_deck_cards(game_state) do
    deck_cards = GameState.deck_to_cards(game_state)
    {:ok, deck_cards}
  end

  defp draw_from_deck([]), do: {:error, :deck_empty}
  defp draw_from_deck([card | remaining]), do: {:ok, card, remaining}

  defp add_card_to_hand(player_state, card) do
    PlayerGameState.add_cards_to_hand(player_state, [card])
  end

  defp update_deck(game_state, remaining_cards) do
    deck_data = GameState.cards_to_deck(remaining_cards)

    GameState.game_data_changeset(game_state, %{deck: deck_data})
    |> Repo.update()
  end

  defp get_next_player_index(game_state) do
    current_index = game_state.current_player_index
    player_count = length(game_state.turn_order)
    rem(current_index + 1, player_count)
  end
end
