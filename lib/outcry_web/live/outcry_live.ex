defmodule OutcryWeb.OutcryLive do
  use Phoenix.{LiveView, HTML}
  use OutcryWeb.LiveAuth, otp_app: :outcry

  @impl true
  def mount(%{}, session, socket) do
    user_id = case get_user_id(session) do
      {:ok, user_id} -> "user:#{user_id}"
      :error -> "anon:#{Ecto.UUID.generate()}"
    end
    {:ok,
     socket
     |> assign(user_id: user_id, status: :in_queue, errors: []),
     temporary_assigns: [trade_message: nil]}
  end

  @impl true
  def handle_params(%{}, _params, socket) do
    {:ok, _} = Outcry.Matchmaker.join_matchmaking(self(), socket.assigns.user_id)
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        :kick_out,
        %{assigns: %{status: :in_queue}} = socket
      ) do
    {:noreply, socket |> assign(status: :kicked_out)}
  end

  @impl true
  def handle_info(
        %{event: "game_start", game_pid: game_pid},
        %{assigns: %{status: :in_queue}} = socket
      ) do
    :ok = Outcry.Matchmaker.leave_matchmaking(self(), socket.assigns.user_id)
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
    {:ok, _} = Outcry.Matchmaker.join_matchmaking(self(), socket.assigns.user_id)
    {:noreply, socket |> assign(status: :in_queue)}
  end

  @impl true
  def handle_event("clear_errors", _params, socket) do
    {:noreply, socket |> assign(errors: [])}
  end

  @impl true
  def render(assigns) do
    ~L"""
    <%= case @status do %>
      <% :in_queue -> %> <h1 class="title is-1">Looking for game...</h1>
      <% :game_started -> %>
      <%= Phoenix.View.render(OutcryWeb.GameView, "error.html", assigns) %>
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
      <h1 class="title is-1">Left queue</h1>
      <div class="content">
        <p>It looks like you joined the queue again with this account.
        You have been exited from the queue on this tab.</p>
        <p><a href="javascript:window.location.reload(true)">Click here to rejoin the queue in this tab.</a></p>
      </div>
    <% end %>
    """
  end
end
