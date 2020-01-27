defmodule Outcry.Game do
  defmodule Player do
    def game_start(pid, game_pid) do
      send(pid, %{event: "game_start", game_pid: game_pid})
    end

    def state_update(pid, state) do
      send(pid, %{event: "state_update", state: state})
    end

    def trade(pid, trade_message) do
      send(pid, Map.put(trade_message, :event, "trade"))
    end

    def game_over(pid, score_info) do
      send(pid, %{event: "game_over", score_info: score_info})
    end

    def place_order(pid, game_pid, order) do
      Outcry.Game.place_order(game_pid, pid, order)
    end
  end

  use GenServer, restart: :transient
  alias Outcry.Game.Orders
  alias Outcry.Game.Types.{Suit, Direction}

  @nice_ids ~w(Q W E R)

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @game_length 120_000

  @impl true
  def init(args) do
    Process.send_after(self(), :end_game, @game_length)
    {:ok, %{}, {:continue, Map.put(args, :event, "start_game")}}
  end

  defp broadcast_to_players(f, state) do
    state.players |> Map.keys() |> Enum.each(f)
  end

  defp clear_order_books(state) do
    empty_order_book = %{buy: [], sell: []}
    state |> Map.put(:order_books, Map.new(Suit.all_suits(), &{&1, empty_order_book}))
  end

  @distribution [8, 10, 10, 12]
  @initial_wealth 0

  @impl true
  def handle_continue(%{event: "start_game", players: players}, state) do
    card_distribution = Map.new(Enum.zip(Suit.all_suits(), Enum.shuffle(@distribution)))

    {common_suit, 12} = Enum.max_by(card_distribution, fn {_suit, count} -> count end)
    goal_suit = Suit.opposite_suit(common_suit)

    deck =
      Enum.flat_map(card_distribution, fn {suit, count} -> List.duplicate(suit, count) end)
      |> Enum.shuffle()

    initial_counts = Map.new(Suit.all_suits(), &{&1, 0})

    count_suits = fn raw_hand ->
      Enum.reduce(raw_hand, initial_counts, fn suit, counts ->
        Map.update!(counts, suit, &(&1 + 1))
      end)
    end

    hands =
      deck
      |> Enum.chunk_every(10)
      |> Enum.map(count_suits)
      |> (&Enum.zip(players, &1)).()
      |> Map.new()

    handle_continue(%{event: "start_game", hands: hands, goal_suit: goal_suit}, state)
  end

  @impl true
  def handle_continue(%{event: "start_game", hands: hands, goal_suit: goal_suit}, state) do
    players =
      hands
      |> Enum.zip(@nice_ids)
      |> Map.new(fn {{player_id, hand}, nice_id} ->
        {player_id, %{wealth: @initial_wealth, hand: hand, nice_id: nice_id}}
      end)

    {:noreply,
     state
     |> Map.put(:players, players)
     |> Map.put(:goal_suit, goal_suit)
     |> Map.put(:trade_id, 0)
     |> clear_order_books(), {:continue, :broadcast_start}}
  end

  @and_then_broadcast_state {:continue, :broadcast_state}

  @impl true
  def handle_continue(:broadcast_start, state) do
    broadcast_to_players(&Player.game_start(&1, self()), state)
    {:noreply, state, @and_then_broadcast_state}
  end

  @impl true
  def handle_continue(:broadcast_state, state) do
    broadcast_to_players(&Player.state_update(&1, state), state)
    {:noreply, state}
  end

  @impl true
  def handle_continue({:broadcast_trade, trade_message}, state) do
    broadcast_to_players(&Player.trade(&1, trade_message), state)
    {:noreply, state, @and_then_broadcast_state}
  end

  defp increment_trade_id(state) do
    update_in(state.trade_id, &(&1 + 1))
  end

  defp cancel_conflicting_orders(order_book_side, player) do
    Enum.reject(order_book_side, fn {p, _} -> p == player end)
  end

  defp try_order(state, player, %Orders.Limit{suit: suit, direction: direction, price: price}) do
    other_direction = Direction.opposite_direction(direction)
    other_side = state.order_books[suit][other_direction]

    case other_side do
      [] ->
        :nocross

      [{other_player, other_price} | _rest_of_book] ->
        other_direction_int = Direction.direction_to_int(other_direction)

        if (other_price - price) * other_direction_int >= 0 do
          if player == other_player do
            # TODO: maybe recurse and check next order?
            :selftrade
          else
            sides = %{direction => player, other_direction => other_player}
            {:cross, {sides, other_price}}
          end
        else
          :nocross
        end
    end
  end

  defp try_order(state, player, %Orders.Market{suit: suit, direction: direction}) do
    fake_order = %Orders.Limit{
      suit: suit,
      direction: direction,
      price: 1_000 * Direction.direction_to_int(direction)
    }

    try_order(state, player, fake_order)
  end

  def place_order(server, player, order) do
    case order.__struct__.changeset(order) do
      {:ok, order} ->
        GenServer.cast(server, %{
          player: player,
          order: order
        })

      {:error, %{errors: errors}} ->
        {:error, errors}
    end
  end

  defp worse?(direction_as_int, price0, price1) do
    price0 * direction_as_int < price1 * direction_as_int
  end

  defp add_to_order_book(state, player, %Orders.Limit{
         suit: suit,
         direction: direction,
         price: price
       }) do
    direction_as_int = Direction.direction_to_int(direction)

    update_in(state.order_books[suit][direction], fn order_book_half ->
      {not_worse_than_order, worse_than_order} =
        order_book_half
        |> (&cancel_conflicting_orders(&1, player)).()
        |> Enum.split_while(fn {_, other_price} ->
          not worse?(direction_as_int, other_price, price)
        end)

      not_worse_than_order ++ [{player, price} | worse_than_order]
    end)
  end

  defp execute_trade(state, order, {sides, cross_price} = _trade) do
    suit = order.suit

    update_wealth = fn state, {direction, player} ->
      update_in(
        state.players[player].wealth,
        &(&1 - cross_price * Direction.direction_to_int(direction))
      )
    end

    update_hand = fn state, {direction, player} ->
      update_in(
        state.players[player].hand[suit],
        &(&1 + Direction.direction_to_int(direction))
      )
    end

    execute = fn order_side, state ->
      state |> update_wealth.(order_side) |> update_hand.(order_side)
    end

    _new_state = Enum.reduce(sides, state, execute) |> increment_trade_id() |> clear_order_books()
  end

  defp has_card?(state, player, suit) do
    state.players[player].hand[suit] > 0
  end

  defp short_sell?(state, player, order) do
    order.direction == :sell and not has_card?(state, player, order.suit)
  end

  @impl true
  def handle_cast(
        %{player: player, order: %Orders.Cancel{suit: suit, direction: direction}},
        state
      ) do
    new_state =
      update_in(state.order_books[suit][direction], &cancel_conflicting_orders(&1, player))

    {:noreply, new_state, @and_then_broadcast_state}
  end

  @impl true
  def handle_cast(%{player: player, order: order}, state) do
    if short_sell?(state, player, order) do
      {:noreply, state}
    else
      case try_order(state, player, order) do
        :nocross ->
          case order.__struct__ do
            # Only limit orders can be added to the book.
            Orders.Limit ->
              new_state = add_to_order_book(state, player, order)
              {:noreply, new_state, @and_then_broadcast_state}

            _ ->
              {:noreply, state}
          end

        {:cross, trade} ->
          new_state = execute_trade(state, order, trade)

          {:noreply, new_state,
           {:continue,
            {:broadcast_trade, %{trade_id: state.trade_id, trade: trade, order: order}}}}

        :selftrade ->
          {:noreply, state}
      end
    end
  end

  @total_goal 200
  @points_per_goal 10

  defp score(%{players: players, goal_suit: goal_suit} = _state) do
    wealth_points = Map.new(players, fn {player_id, player} -> {player_id, player.wealth} end)

    goal_points =
      Map.new(players, fn {player_id, player} ->
        {player_id, @points_per_goal * player.hand[goal_suit]}
      end)

    goal_points_only = Map.values(goal_points)
    nonbonus_goal_points = Enum.sum(goal_points_only)

    most_goal_points = Enum.max(goal_points_only)
    winners = Enum.filter(goal_points, fn {_, points} -> points == most_goal_points end)
    winners_bonus = (@total_goal - nonbonus_goal_points) / length(winners)

    winners_points =
      Map.new(winners, fn {player_id, ^most_goal_points} -> {player_id, winners_bonus} end)

    sum_points = fn _, u, v -> u + v end

    final_scores =
      wealth_points
      |> Map.merge(goal_points, sum_points)
      |> Map.merge(winners_points, sum_points)

    %{final_scores: final_scores, goal_suit: goal_suit}
  end

  defp end_game(state) do
    score_info = score(state)
    broadcast_to_players(&Player.game_over(&1, score_info), state)
    state |> Map.put(:score_info, score_info)
  end

  @impl true
  def handle_info(:end_game, state) do
    final_state = end_game(state)
    {:stop, :normal, final_state}
  end

  @impl true
  def terminate(_, _state) do
    # TODO: log result to database
  end
end
