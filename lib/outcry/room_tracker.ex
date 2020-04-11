defmodule Outcry.RoomPresence do
  use Phoenix.Presence, otp_app: :outcry,
                        pubsub_server: Outcry.PubSub
end

defmodule Outcry.RoomTracker do
  use GenServer

  @required_users 4

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  defp topic_of_room(room) do
    "room:" <> room
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  def create_room(%{room: _room, pid: _pid, user_id: _user_id} = info) do
    GenServer.call(__MODULE__, {:create_room, info})
  end

  def join_room(%{room: _room, pid: _pid, user_id: _user_id} = info) do
    GenServer.call(__MODULE__, {:join_room, info})
  end

  def leave_room(%{room: _room, pid: _pid, user_id: _user_id} = info) do
    GenServer.call(__MODULE__, {:leave_room, info})
  end

  def start_room(%{room: _room, pid: _pid, user_id: _user_id} = info) do
    GenServer.call(__MODULE__, {:start_room, info})
  end

  def game_done(%{room: _room} = info) do
    GenServer.call(__MODULE__, {:game_done, info})
  end

  @impl true
  def handle_call({:create_room, %{room: room, pid: _pid, user_id: _user_id} = info}, from, state) do
    case Map.get(state, room) do
      nil ->
        new_state = state |> Map.put(room, %{room_state: :not_started})
        handle_call({:join_room, info}, from, new_state)
      %{room_state: :started} -> 
        {:reply, {:error, "Room already exists."}, state}
      %{room_state: :not_started} -> 
        {:reply, {:error, "Room already exists."}, state}
    end
  end

  @impl true
  def handle_call({:join_room, %{room: room, pid: pid, user_id: user_id}}, _from, state) do
    case Map.get(state, room) do
      nil -> {:reply, {:error, "Room does not exist."}, state}
      %{room_state: :started} -> {:reply, {:error, "Room has already started."}, state}
      
      %{room_state: :not_started} ->
        topic = topic_of_room(room)
        case Outcry.RoomPresence.get_by_key(topic, user_id) do
          %{metas: [%{pid: other_pid}]} ->
            {:reply, :ok, _} = handle_call({:leave_room, %{room: room, pid: other_pid, user_id: user_id}}, other_pid, state)
            send(other_pid, :kick_out)

          [] -> nil
        end

        users_in_room = room |> topic_of_room() |> Outcry.RoomPresence.list() |> map_size()
        response = if users_in_room >= @required_users do
          {:error, "Too many users in the room."}
        else
          Outcry.RoomPresence.track(pid, topic, user_id, %{pid: pid})
          :ok
        end
        {:reply, response, state}
    end
  end

  @impl true
  def handle_call({:leave_room, %{room: room, pid: pid, user_id: user_id}}, _from, state) do
    Outcry.RoomPresence.untrack(pid, topic_of_room(room), user_id)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:start_room, %{room: room, pid: _pid, user_id: _user_id}}, _from, state) do
    users_in_room = room |> topic_of_room() |> Outcry.RoomPresence.list()

    if map_size(users_in_room) < @required_users do
      {:reply, {:error, "Not enough users in room."}, state}
    else
      @required_users = map_size(users_in_room)
      pid_to_player_id = Map.new(users_in_room, fn {player_id, %{metas: [%{pid: pid}]}} ->
        {pid, player_id}
      end)

      {:ok, _} = Outcry.GameSupervisor.start_child(%{pid_to_player_id: pid_to_player_id, room: room})
      {:reply, :ok, state |> update_in([room, :room_state], fn :not_started -> :started end)}
    end
  end

  @impl true
  def handle_call({:game_done, %{room: room}}, _from, state) do
    {:reply, :ok, state |> update_in([room, :room_state], fn :started -> :not_started end)}
  end
end
