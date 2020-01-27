defmodule Outcry.GameTest do
  use ExUnit.Case, async: true
  alias Outcry.Game.Orders.{Limit, Market, Cancel}
  alias Outcry.Game
  alias Game.Player

  @initial_args %{
    hands: [
      %{h: 8, j: 0, k: 2, l: 0},
      %{h: 0, j: 10, k: 0, l: 0},
      %{h: 0, j: 0, k: 10, l: 0},
      %{h: 0, j: 0, k: 0, l: 10}
    ],
    goal_suit: :j
  }

  defmodule FakePlayer do
    use GenServer

    def start_link(args) do
      GenServer.start_link(__MODULE__, args)
    end

    @impl true
    def init(%{parent_pid: _} = state) do
      {:ok, state}
    end

    @impl true
    def handle_info(event, %{parent_pid: parent_pid} = state) do
      case event do
        %{event: "state_update", state: player_state} ->
          {:noreply, state |> Map.put(:player_state, player_state)}

        _ ->
          send(parent_pid, {self(), event})
          {:noreply, state}
      end
    end

    @impl true
    def handle_call(:state, _from, state) do
      {:reply, Map.get(state, :player_state), state}
    end

    def get_state(player) do
      GenServer.call(player, :state)
    end
  end

  setup do
    players =
      Enum.map(1..4, fn id ->
        start_supervised!({FakePlayer, %{parent_pid: self()}}, id: id)
      end)

    args = update_in(@initial_args.hands, &Map.new(Enum.zip(players, &1)))
    game = start_supervised!({Outcry.Game, args})

    %{game: game, players: players, args: args}
  end

  test "game starts", %{game: game, players: players} do
    Enum.each(players, fn player ->
      assert_receive {^player, %{event: "game_start", game_pid: ^game}}
    end)
  end

  @extra_wait_time 100

  defmacro assert_player_state(player, state) do
    quote do
      player = unquote(player)
      Process.sleep(@extra_wait_time)
      assert %{players: %{^player => unquote(state)}} = FakePlayer.get_state(player)
    end
  end

  test "simple trade works", %{game: game, players: players} do
    [player_h, player_j | _] = players
    sell_order = %Limit{suit: :h, direction: :sell, price: 5}

    assert_player_state(player_h, %{hand: %{h: 8}})
    assert_player_state(player_j, %{hand: %{h: 0}})
    assert :ok = Player.place_order(player_h, game, sell_order)
    assert :ok = Player.place_order(player_j, game, %{sell_order | direction: :buy})
    assert_player_state(player_h, %{hand: %{h: 7}, wealth: 5})
    assert_player_state(player_j, %{hand: %{h: 1}, wealth: -5})
  end

  test "trade uses standing order price", %{game: game, players: players} do
    [player_h, player_j | _] = players
    sell_order = %Limit{suit: :h, direction: :sell, price: 5}
    buy_order = %Limit{suit: :h, direction: :buy, price: 10}

    assert_player_state(player_h, %{hand: %{h: 8}})
    assert_player_state(player_j, %{hand: %{h: 0}})
    assert :ok = Player.place_order(player_h, game, sell_order)
    assert :ok = Player.place_order(player_j, game, buy_order)
    assert_player_state(player_h, %{hand: %{h: 7}, wealth: 5})
    assert_player_state(player_j, %{hand: %{h: 1}, wealth: -5})
  end

  test "trade uses best price", %{game: game, players: players} do
    [player_h, player_j, player_k | _] = players
    sell_order = %Limit{suit: :k, direction: :sell, price: 5}

    assert_player_state(player_h, %{hand: %{k: 2}})
    assert_player_state(player_j, %{hand: %{k: 0}})
    assert_player_state(player_k, %{hand: %{k: 10}})
    assert :ok = Player.place_order(player_h, game, sell_order)
    assert :ok = Player.place_order(player_k, game, %{sell_order | price: 4})
    assert :ok = Player.place_order(player_j, game, %{sell_order | direction: :buy})
    assert_player_state(player_h, %{hand: %{k: 2}, wealth: 0})
    assert_player_state(player_j, %{hand: %{k: 1}, wealth: -4})
    assert_player_state(player_k, %{hand: %{k: 9}, wealth: 4})
  end

  test "trade uses first time when price conflicts", %{game: game, players: players} do
    [player_h, player_j, player_k | _] = players
    sell_order = %Limit{suit: :k, direction: :sell, price: 5}

    assert_player_state(player_h, %{hand: %{k: 2}})
    assert_player_state(player_j, %{hand: %{k: 0}})
    assert_player_state(player_k, %{hand: %{k: 10}})
    assert :ok = Player.place_order(player_h, game, sell_order)
    assert :ok = Player.place_order(player_k, game, sell_order)
    assert :ok = Player.place_order(player_j, game, %{sell_order | direction: :buy})
    assert_player_state(player_h, %{hand: %{k: 1}, wealth: 5})
    assert_player_state(player_j, %{hand: %{k: 1}, wealth: -5})
    assert_player_state(player_k, %{hand: %{k: 10}, wealth: 0})
  end

  test "market order works", %{game: game, players: players} do
    [player_h, player_j | _] = players
    market_order = %Market{suit: :k, direction: :sell}
    buy_order = %Limit{suit: :k, direction: :buy, price: 200}

    assert_player_state(player_h, %{hand: %{k: 2}})
    assert_player_state(player_j, %{hand: %{k: 0}})
    assert :ok = Player.place_order(player_j, game, buy_order)
    assert :ok = Player.place_order(player_h, game, market_order)
    assert_player_state(player_h, %{hand: %{k: 1}, wealth: 200})
    assert_player_state(player_j, %{hand: %{k: 1}, wealth: -200})
  end

  test "market order selects best price", %{game: game, players: players} do
    [player_h, player_j, player_k | _] = players
    sell_order = %Limit{suit: :k, direction: :sell, price: 5}
    market_order = %Market{suit: :k, direction: :buy}

    assert_player_state(player_h, %{hand: %{k: 2}})
    assert_player_state(player_j, %{hand: %{k: 0}})
    assert_player_state(player_k, %{hand: %{k: 10}})
    assert :ok = Player.place_order(player_h, game, sell_order)
    # next order is better and should get filled
    assert :ok = Player.place_order(player_k, game, %{sell_order | price: 4})
    assert :ok = Player.place_order(player_j, game, market_order)
    assert_player_state(player_h, %{hand: %{k: 2}, wealth: 0})
    assert_player_state(player_j, %{hand: %{k: 1}, wealth: -4})
    assert_player_state(player_k, %{hand: %{k: 9}, wealth: 4})
  end

  test "failed market order not on books", %{game: game, players: players} do
    [player_h, player_j | _] = players
    market_order = %Market{suit: :k, direction: :sell}
    buy_order = %Limit{suit: :k, direction: :buy, price: 200}

    assert_player_state(player_h, %{hand: %{k: 2}})
    assert_player_state(player_j, %{hand: %{k: 0}})
    # next order killed
    assert :ok = Player.place_order(player_h, game, market_order)
    # next order does not hit market order above
    assert :ok = Player.place_order(player_j, game, buy_order)
    assert_player_state(player_h, %{hand: %{k: 2}, wealth: 0})
    assert_player_state(player_j, %{hand: %{k: 0}, wealth: 0})
  end

  test "cancel order explicitly", %{game: game, players: players} do
    [player_h, player_j | _] = players
    sell_order = %Limit{suit: :h, direction: :sell, price: 5}

    assert_player_state(player_h, %{hand: %{h: 8}})
    assert_player_state(player_j, %{hand: %{h: 0}})
    assert :ok = Player.place_order(player_h, game, sell_order)
    assert :ok = Player.place_order(player_h, game, %Cancel{suit: :h, direction: :sell})
    assert :ok = Player.place_order(player_j, game, %{sell_order | direction: :buy})
    assert_player_state(player_h, %{hand: %{h: 8}})
    assert_player_state(player_j, %{hand: %{h: 0}})
  end

  test "conflicting order cancels existing", %{game: game, players: players} do
    [player_h, player_j | _] = players
    sell_order = %Limit{suit: :h, direction: :sell}
    buy_order = %{sell_order | direction: :buy}

    assert_player_state(player_h, %{hand: %{h: 8}})
    assert_player_state(player_j, %{hand: %{h: 0}})
    assert :ok = Player.place_order(player_h, game, %{sell_order | price: 5})
    assert :ok = Player.place_order(player_h, game, %{sell_order | price: 6})
    assert :ok = Player.place_order(player_j, game, %{buy_order | price: 5})
    assert_player_state(player_h, %{hand: %{h: 8}})
    assert_player_state(player_j, %{hand: %{h: 0}})
    assert :ok = Player.place_order(player_j, game, %{buy_order | price: 6})
    assert_player_state(player_h, %{hand: %{h: 7}})
    assert_player_state(player_j, %{hand: %{h: 1}})
  end

  test "trade clears all suits", %{game: game, players: players} do
    [player_h, player_j | _] = players
    sell_order_h = %Limit{suit: :h, direction: :sell, price: 5}
    sell_order_k = %{sell_order_h | suit: :k}

    assert_player_state(player_h, %{hand: %{h: 8}})
    assert_player_state(player_j, %{hand: %{h: 0}})
    assert_player_state(player_h, %{hand: %{k: 2}})
    assert_player_state(player_j, %{hand: %{k: 0}})
    assert :ok = Player.place_order(player_h, game, sell_order_h)
    # next order will be cleared by trade in h suit
    assert :ok = Player.place_order(player_h, game, sell_order_k)
    assert :ok = Player.place_order(player_j, game, %{sell_order_h | direction: :buy})
    assert_player_state(player_h, %{hand: %{h: 7}, wealth: 5})
    assert_player_state(player_j, %{hand: %{h: 1}, wealth: -5})
    assert :ok = Player.place_order(player_j, game, %{sell_order_k | direction: :buy})
    # trade in k suit does not happen
    assert_player_state(player_h, %{hand: %{k: 2}, wealth: 5})
    assert_player_state(player_j, %{hand: %{k: 0}, wealth: -5})
  end

  test "short sell denied", %{game: game, players: players} do
    [player_h, player_j | _] = players
    sell_order = %Limit{suit: :j, direction: :sell, price: 5}

    assert_player_state(player_h, %{hand: %{j: 0}})
    # next order denied
    assert :ok = Player.place_order(player_h, game, sell_order)
    # next order does not hit denied order above
    assert :ok = Player.place_order(player_j, game, %{sell_order | direction: :buy})
    assert_player_state(player_h, %{hand: %{j: 0}, wealth: 0})
  end

  test "blantantly invalid orders denied", %{game: game, players: players} do
    [player_h | _] = players
    too_large_order = %Limit{suit: :h, direction: :buy, price: +1_000_000}
    too_small_order = %Limit{suit: :h, direction: :buy, price: -1_000_000}

    Enum.each(
      [%Limit{}, %Market{}, %Cancel{}, too_large_order, too_small_order],
      fn bad_order ->
        assert {:error, _} = Player.place_order(player_h, game, bad_order)
      end
    )
  end

  test "basic end game scores", %{game: game, players: players} do
    player_j = Enum.fetch!(players, 1)

    final_scores =
      Map.new(players, fn player ->
        {player, if(player == player_j, do: 200.0, else: 0)}
      end)

    send(game, :end_game)

    Enum.each(players, fn player ->
      assert_receive {^player,
                      %{
                        event: "game_over",
                        score_info: %{final_scores: ^final_scores, goal_suit: :j}
                      }}
    end)
  end

  test "end game includes wealth", %{game: game, players: players} do
    final_scores = Map.new(Enum.zip(players, [5, 195.0, 0, 0]))

    [player_h, player_j | _] = players
    sell_order = %Limit{suit: :h, direction: :sell, price: 5}

    assert_player_state(player_h, %{hand: %{h: 8}})
    assert_player_state(player_j, %{hand: %{h: 0}})
    assert :ok = Player.place_order(player_h, game, sell_order)
    assert :ok = Player.place_order(player_j, game, %{sell_order | direction: :buy})
    assert_player_state(player_h, %{hand: %{h: 7}, wealth: 5})
    assert_player_state(player_j, %{hand: %{h: 1}, wealth: -5})

    send(game, :end_game)

    Enum.each(players, fn player ->
      assert_receive {^player,
                      %{
                        event: "game_over",
                        score_info: %{final_scores: ^final_scores, goal_suit: :j}
                      }}
    end)
  end

  test "end game users tie", %{game: game, players: players} do
    final_scores = Map.new(Enum.zip(players, [95.0, 105.0, 0, 0]))

    [player_h, player_j | _] = players
    buy_order = %Limit{suit: :j, direction: :buy, price: 1}

    Enum.each(1..5, fn _ ->
      assert :ok = Player.place_order(player_h, game, buy_order)
      assert :ok = Player.place_order(player_j, game, %{buy_order | direction: :sell})
    end)

    send(game, :end_game)

    Enum.each(players, fn player ->
      assert_receive {^player,
                      %{
                        event: "game_over",
                        score_info: %{final_scores: ^final_scores, goal_suit: :j}
                      }}
    end)
  end

  test "fuzz game state", %{game: game, players: players} do
    Enum.each(1..10000, fn _ ->
      type = Enum.random([Limit, Market, Cancel])
      player = Enum.random(players)
      suit = Enum.random(~w(h j k l)a)
      direction = Enum.random(~w(buy sell)a)

      order =
        case type do
          Limit ->
            price = Enum.random(0..200)
            %Limit{suit: suit, direction: direction, price: price}

          Market ->
            %Market{suit: suit, direction: direction}

          Cancel ->
            %Cancel{suit: suit, direction: direction}
        end

      assert :ok = Player.place_order(player, game, order)
    end)

    send(game, :end_game)

    Enum.each(players, fn player ->
      assert_receive {^player,
                      %{
                        event: "game_over",
                        score_info: %{final_scores: final_scores, goal_suit: :j}
                      }}

      assert Enum.sum(Map.values(final_scores)) == 200
    end)
  end
end
