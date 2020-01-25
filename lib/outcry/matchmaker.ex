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
    pids = Enum.map(group, fn {_uid, %{metas: [%{pid: pid}]}} -> pid end)
    {:ok, _} = Outcry.GameSupervisor.start_child(%{players: pids})
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
