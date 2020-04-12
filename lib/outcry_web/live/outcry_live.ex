defmodule OutcryWeb.OutcryLive do
  use Phoenix.LiveView, layout: {OutcryWeb.LayoutView, "game.html"}
  use Phoenix.HTML
  use OutcryWeb.LiveAuth, otp_app: :outcry

  @impl true
  def mount(%{}, session, socket) do
    user_id =
      if connected?(socket) do
        case get_user_id(session) do
          {:ok, user_id} -> "user:#{user_id}"
          :error -> "anon:#{Ecto.UUID.generate()}"
        end
      else
        nil
      end

    {:ok,
     socket
     |> assign(user_id: user_id)
     |> assign_new(:errors, fn -> [] end)
     |> assign_new(:status, fn -> nil end),
     temporary_assigns: [trade_message: nil]}
  end

  defp redirect_to_lobby(socket) do
    socket |> push_patch(to: "/play", replace: true)
  end

  defp redirect_to_room(socket, room) do
    room_query = URI.encode_query(%{room: room})
    socket |> push_patch(to: "/play?#{room_query}", replace: true)
  end

  defp join_lobby(socket) do
    case Outcry.RoomTracker.join_lobby(%{pid: self(), user_id: socket.assigns.user_id}) do
      {:ok, lobby} ->
        socket |> assign(status: :in_lobby, lobby: lobby, errors: [])
      {:error, error} ->
        socket |> assign(errors: [error])
    end
  end

  @impl true
  def handle_params(%{"room" => room_name}, _uri, socket) do
    if connected?(socket) do
      case Outcry.RoomTracker.join_room(%{pid: self(), user_id: socket.assigns.user_id, room: room_name}) do
        :ok ->
          {:noreply, socket |> assign(status: :in_room, room: %{name: room_name, players: []}, errors: [])}
        {:error, error} ->
          {:noreply, socket |> assign(errors: [error]) |> redirect_to_lobby()}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_params(%{}, _uri, socket) do
    if connected?(socket) do
      case socket.assigns.status do
        :in_lobby -> {:noreply, socket}
        _ -> {:noreply, join_lobby(socket)}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(
        :kick_out,
        %{assigns: %{status: status}} = socket
      ) when status == :in_queue or status == :in_lobby do
    {:noreply, socket |> assign(status: :kicked_out)}
  end

  @impl true
  def handle_info(
        %{event: "game_start", game_pid: game_pid},
        %{assigns: %{status: :in_queue}} = socket
      ) do
    {:noreply, socket |> assign(status: :game_starting, game_pid: game_pid)}
  end

  @impl true
  def handle_info(%{event: "state_update", state: state}, socket) do
    # LiveView change tracking only tracks assigns directly,
    # so we flatten our state a little here.
    # TODO: flatten more?
    order_books = reverse_order_book_buys(state.order_books)

    {:noreply,
     socket |> assign(players: state.players, order_books: order_books, status: :game_started)}
  end

  @impl true
  def handle_info(%{event: "trade"} = trade_message, socket) do
    {:noreply, socket |> assign(trade_message: trade_message)}
  end

  @impl true
  def handle_info(%{event: "game_over", score_info: score_info}, socket) do
    {:noreply, socket |> assign(status: :game_over, score_info: score_info)}
  end

  @impl true
  def handle_info(%{event: "lobby_update", room: room, num_players_in_room: num_players_in_room}, socket) do
    {:noreply, socket |> update(:lobby, &Map.put(&1, room, num_players_in_room))}
  end

  @impl true
  def handle_info(%{event: "room_update", players_in_room: players}, socket) do
    {:noreply, socket |> update(:room, &Map.put(&1, :players, players))}
  end

  defp reverse_order_book_buys(order_books) do
    Map.new(order_books, fn {suit, order_book} ->
      {suit, update_in(order_book.buy, &Enum.reverse/1)}
    end)
  end

  @trades_per_second 4
  defp rate_limit(socket) do
    case ExRated.check_rate(socket.assigns.user_id, 1_000, @trades_per_second) do
      {:error, _} -> {:error, ["Trading too fast, wait one second."]}
      {:ok, _} = ok -> ok
    end
  end

  defp to_struct(kind, attrs) do
    struct = struct(kind)

    Enum.reduce(Map.to_list(struct), struct, fn {k, _}, acc ->
      case Map.fetch(attrs, Atom.to_string(k)) do
        {:ok, v} -> %{acc | k => v}
        :error -> acc
      end
    end)
  end

  defp get_order_type(order) do
    alias Outcry.Game.Orders.{Limit, Market, Cancel}

    case Map.get(order, "type") do
      "limit" -> {:ok, Limit}
      "market" -> {:ok, Market}
      "cancel" -> {:ok, Cancel}
      _ -> {:error, ["Invalid order type."]}
    end
  end

  @impl true
  def handle_event("create_room", %{"create_room" => %{"name" => room_name}}, socket) do
    case Outcry.RoomTracker.create_room(%{pid: self(), user_id: socket.assigns.user_id, room: room_name}) do
      :ok ->
        {:noreply, socket |> redirect_to_room(room_name)}
      {:error, error} ->
        {:noreply, socket |> assign(errors: [error]) |> redirect_to_lobby()}
    end
  end

  @impl true
  def handle_event("join_room", %{"join_room" => %{"name" => name}}, socket) do
    {:noreply, socket |> redirect_to_room(name)}
  end

  @impl true
  def handle_event("order", %{"order" => order}, socket) do
    with {:ok, _} <- rate_limit(socket),
         {:ok, order_type} <- get_order_type(order),
         order <- to_struct(order_type, order),
         :ok <- Outcry.Game.Player.place_order(self(), socket.assigns.game_pid, order) do
      {:noreply, socket |> assign(errors: [])}
    else
      {:error, error_messages} ->
        {:noreply, socket |> assign(errors: error_messages)}
    end
  end

  @impl true
  def handle_event("requeue", _params, socket) do
    {:noreply, socket |> assign(status: :in_queue)}
  end

  @impl true
  def handle_event("clear_errors", _params, socket) do
    {:noreply, socket |> assign(errors: [])}
  end

  @impl true
  def render(assigns) do
    ~L"""
    <%= Phoenix.View.render(OutcryWeb.GameView, "error.html", assigns) %>
    <%= case @status do %>
      <% nil -> %>
      <% :in_lobby -> %>
      <%= Phoenix.View.render(OutcryWeb.GameView, "lobby.html", assigns) %>
      <% :in_room -> %>
      <%= Phoenix.View.render(OutcryWeb.GameView, "room.html", assigns) %>
      <% :game_started -> %>
      <div class="tile is-ancestor">
        <div class="tile is-parent is-vertical">
          <div class="tile is-parent">
            <%= Phoenix.View.render(OutcryWeb.GameView, "points.html", assigns) %>
            <%= Phoenix.View.render(OutcryWeb.GameView, "order_book.html", assigns) %>
            <%= Phoenix.View.render(OutcryWeb.GameView, "trade_history.html", assigns) %>
          </div>
          <div class="tile is-parent" phx-update="ignore">
            <div class="tile is-child is-3"></div>
            <%= Phoenix.View.render(OutcryWeb.GameView, "order_form.html", %{}) %>
            <%= Phoenix.View.render(OutcryWeb.GameView, "timer.html", %{}) %>
          </div>
        </div>
      </div>
      <% :game_starting -> %>
      <% :game_over -> %>
      <div class="tile is-ancestor">
        <div class="tile is-parent">
          <%= Phoenix.View.render(OutcryWeb.GameView, "final_score.html", assigns) %>
        </div>
      </div>
      <% :kicked_out -> %>
      <h1 class="title is-1">Left room</h1>
      <div class="content">
        <p>It looks like you joined the room again with this account in a different tab.
        You have been exited from the room on this tab.</p>
        <p><a href="javascript:window.location.reload(true)">Click here to rejoin the room in this tab.</a></p>
      </div>
    <% end %>
    """
  end
end
