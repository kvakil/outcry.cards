defmodule Outcry.RoomPresence do
  use Phoenix.Presence,
    otp_app: :outcry,
    pubsub_server: Outcry.PubSub
end

defmodule Outcry.RoomTracker do
  use GenServer

  @required_users 4
  @lobby "@lobby"

  def start_link([]) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  defp topic_of_room(room) do
    "room:" <> room
  end

  @impl true
  def init(state) do
    :ok = OutcryWeb.Endpoint.subscribe(topic_of_room("@public"))
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

  def join_lobby(%{pid: _pid, user_id: _user_id} = info) do
    GenServer.call(__MODULE__, {:join_lobby, info})
  end

  def leave_lobby(%{pid: _pid, user_id: _user_id} = info) do
    GenServer.call(__MODULE__, {:leave_lobby, info})
  end

  defp can_start_room(users_in_room) do
    case map_size(users_in_room) do
      @required_users -> :ok
      _ -> {:error, "Not enough users in room."}
    end
  end

  @impl true
  def handle_call({:create_room, %{room: room, pid: _pid, user_id: _user_id} = info}, from, state) do
    case Map.get(state, room) do
      nil ->
        :ok = OutcryWeb.Endpoint.subscribe(topic_of_room(room))
        {:reply, :ok, state |> Map.put(room, %{room_state: :not_started, num_players: 0})}

      %{room_state: :started} ->
        {:reply, {:error, "Room already exists."}, state}

      %{room_state: :not_started} ->
        {:reply, {:error, "Room already exists."}, state}
    end
  end

  @impl true
  def handle_call({:join_room, %{room: room, pid: pid, user_id: user_id}}, _from, state) do
    case Map.get(state, room) do
      nil ->
        {:reply, {:error, "Room does not exist."}, state}

      %{room_state: :started} ->
        {:reply, {:error, "Room has already started."}, state}

      %{room_state: :not_started} ->
        topic = topic_of_room(room)

        case Outcry.RoomPresence.get_by_key(topic, user_id) do
          %{metas: [%{pid: other_pid}]} ->
            {:reply, :ok, _} =
              handle_call(
                {:leave_room, %{room: room, pid: other_pid, user_id: user_id}},
                other_pid,
                state
              )

            send(other_pid, :kick_out)

          [] ->
            nil
        end

        users_in_room = topic |> Outcry.RoomPresence.list() |> map_size()

        response =
          if users_in_room >= @required_users do
            {:error, "Too many users in the room."}
          else
            {:ok, _} = Outcry.RoomPresence.track(pid, topic, user_id, %{pid: pid})
            :ok
          end

        {:reply, response, state}
    end
  end

  @impl true
  def handle_call({:leave_room, %{room: room, pid: pid, user_id: user_id}}, _from, state) do
    {:reply, Outcry.RoomPresence.untrack(pid, topic_of_room(room), user_id), state}
  end

  @impl true
  def handle_call({:start_room, %{room: room, pid: _pid, user_id: _user_id}}, _from, state) do
    with topic <- room |> topic_of_room(),
         :ok <- OutcryWeb.Endpoint.subscribe(topic),
         users_in_room <- Outcry.RoomPresence.list(topic),
         :ok <- can_start_room(users_in_room),
         pid_to_player_id <-
           Map.new(users_in_room, fn {player_id, %{metas: [%{pid: pid}]}} ->
             {pid, player_id}
           end),
         {:ok, _pid} <-
           Outcry.GameSupervisor.start_child(%{pid_to_player_id: pid_to_player_id, room: room}) do
      {:reply, :ok, state |> update_in([room, :room_state], fn :not_started -> :started end)}
    else
      {:error, _} = e -> {:reply, e, state}
    end
  end

  @impl true
  def handle_call({:game_done, %{room: room}}, _from, state) do
    {:reply, :ok, state |> update_in([room, :room_state], fn :started -> :not_started end)}
  end

  @impl true
  def handle_call({:join_lobby, %{pid: pid, user_id: user_id}}, _from, state) do
    with {:ok, _} <- Outcry.RoomPresence.track(pid, @lobby, user_id, %{pid: pid}) do
      active_rooms = state |> Map.keys()

      lobby =
        active_rooms
        |> Map.new(&{&1, &1 |> topic_of_room() |> Outcry.RoomPresence.list() |> map_size()})

      {:reply, {:ok, lobby}, state}
    else
      {:error, _} = e -> {:reply, e, state}
    end
  end

  @impl true
  def handle_call({:leave_lobby, %{pid: pid, user_id: user_id}}, _from, state) do
    {:reply, Outcry.RoomPresence.untrack(pid, @lobby, user_id), state}
  end

  @impl true
  def handle_info(
        %{
          event: "presence_diff",
          topic: "room:" <> room
        },
        state
      ) do
    players_in_room =
      room
      |> topic_of_room()
      |> Outcry.RoomPresence.list()

    num_players_in_room = map_size(players_in_room)

    Outcry.RoomPresence.list(@lobby)
    |> Enum.each(fn {_, %{metas: [%{pid: pid}]}} ->
      send(pid, %{event: "lobby_update", room: room, num_players_in_room: num_players_in_room})
    end)

    pids = players_in_room |> Enum.map(fn {_, %{metas: [%{pid: pid}]}} -> pid end)

    pids
    |> Enum.each(fn player_pid ->
      send(player_pid, %{event: "room_update", players_in_room: pids})
    end)

    {:noreply,
     case num_players_in_room do
       0 ->
         state |> Map.delete(room)

       _ ->
         state
     end}
  end
end
