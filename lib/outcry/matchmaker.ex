defmodule Outcry.Matchmaker do
  use GenServer

  @nostate []
  @matchmake_interval 500
  @required_users 4

  def channel, do: "lobby"

  def start_link(@nostate) do
    GenServer.start_link(__MODULE__, @nostate)
  end

  @impl true
  def init(@nostate) do
    schedule_matchmake()
    {:ok, @nostate}
  end

  defp schedule_matchmake do
    Process.send_after(self(), :matchmake, @matchmake_interval)
  end

  defp matchmake(group) when length(group) == @required_users do
    # TODO: what if user is logged in on multiple devices / has multiple
    # tabs open? Then there will be multiple PIDs below.
    # Right now, we just ignore them and only match the first one--but
    # this may lead to users being in multiple games if matchmaking
    # occurs multiple times. We need a better solution.
    pid_to_player_id =
      Map.new(group, fn {player_id, %{metas: [%{pid: pid} | _]}} ->
        {pid, player_id}
      end)

    {:ok, _} = Outcry.GameSupervisor.start_child(%{pid_to_player_id: pid_to_player_id})
  end

  @impl true
  def handle_info(:matchmake, @nostate) do
    OutcryWeb.MatchmakingPresence.list(channel())
    |> Enum.shuffle()
    |> Enum.chunk_every(@required_users, @required_users, :discard)
    |> Enum.each(&matchmake/1)

    schedule_matchmake()
    {:noreply, @nostate}
  end
end
