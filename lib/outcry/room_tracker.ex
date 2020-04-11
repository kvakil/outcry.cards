defmodule Outcry.RoomPresence do
  use Phoenix.Presence, otp_app: :outcry,
                        pubsub_server: Outcry.PubSub
end

defmodule Outcry.RoomTracker do
  use GenServer

  @nostate []
  @matchmake_interval 500
  @required_users 4

  @channel "lobby"

  def start_link(@nostate) do
    GenServer.start_link(__MODULE__, @nostate)
  end

  @impl true
  def init(@nostate) do
    schedule_matchmake()
    {:ok, @nostate}
  end

  def join_matchmaking(pid, user_id) do
    case Outcry.MatchmakingPresence.get_by_key(@channel, user_id) do
      %{metas: [%{pid: other_pid}]} ->
        leave_matchmaking(other_pid, user_id)
        send(other_pid, :kick_out)

      [] -> :ok
    end
    Outcry.MatchmakingPresence.track(pid, @channel, user_id, %{pid: self()})
  end

  def leave_matchmaking(pid, user_id) do
    Outcry.MatchmakingPresence.untrack(pid, @channel, user_id)
  end

  defp schedule_matchmake do
    Process.send_after(self(), :matchmake, @matchmake_interval)
  end

  defp matchmake(group) when length(group) == @required_users do
    pid_to_player_id =
      Map.new(group, fn {player_id, %{metas: [%{pid: pid}]}} ->
        {pid, player_id}
      end)

    {:ok, _} = Outcry.GameSupervisor.start_child(%{pid_to_player_id: pid_to_player_id})
  end

  @impl true
  def handle_info(:matchmake, @nostate) do
    Outcry.MatchmakingPresence.list(@channel)
    |> Enum.shuffle()
    |> Enum.chunk_every(@required_users, @required_users, :discard)
    |> Enum.each(&matchmake/1)

    schedule_matchmake()
    {:noreply, @nostate}
  end
end
