defmodule Outcry.Room do
  use GenServer, restart: :transient

  @players_in_game 4

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init(%{name: name}) do
    {:ok, %{name: name, players: %{}}}
  end

  def add_player(room, player) do
    GenServer.call(room, {:add_player, player})
  end

  def remove_player(room, player) do
    GenServer.call(room, {:remove_player, player})
  end
  
  def start_game(room) do
    GenServer.call(room, {:start_game})
  end

  @impl true
  def handle_call({:add_player, %{name: name, pid: pid}}, _from, %{players: players}) do
    if map_size(players) >= @players_in_game do
      {:reply, {:error, "Room already full."}, state}
    else
      if Map.has_key?(players, name) do
        {:reply, {:error, "That name is already taken."}, state}
      else
        {:reply, :ok, %{players: Map.put(players, name, pid)}}
      end
    end
  end

  @impl true
  def handle_call({:remove_player, %{name: name, pid: pid}}, _from, %{players: players}) do
    {^pid, new_players} = Map.pop!(players, name)
    {:reply, :ok, %{players: new_players}}
  end

  @impl true
  def handle_call({:start_game}, _from, %{players: players} = state) when map_size(players) < @players_in_game do
    {:reply, {:error, "Not enough players to start!"}, state}
  end

  @impl true
  def handle_call({:start_game}, _from, %{players: players} = state) when map_size(players) == @players_in_game do
    pid_to_player_id = Map.new(players, fn {name, pid} -> {pid, name} end)
    @players_in_game = map_size(pid_to_player_id)
    case Outcry.GameSupervisor.start_child(%{pid_to_player_id: pid_to_player_id}) do
      {:ok, _} -> {:stop, :normal, :ok, state}
      _ -> {:reply, {:error, "Error in starting game"}, state}}
    end
  end
end
