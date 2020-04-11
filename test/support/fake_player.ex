defmodule Outcry.FakePlayer do
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
