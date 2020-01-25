defmodule OutcryWeb.OutcryLive do
  use Phoenix.{LiveView, HTML}
  alias OutcryWeb.MatchmakingPresence

  @impl true
  def mount(%{}, socket) do
    {:ok,
     socket
     |> assign(user_id: inspect(self()), status: :in_queue)}
  end

  @impl true
  def handle_params(%{}, _params, socket) do
    channel = Outcry.Matchmaker.channel()
    {:ok, _} = MatchmakingPresence.track(self(), channel, socket.assigns.user_id, %{pid: self()})

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        %{event: "game_start", game_pid: game_pid},
        %{assigns: %{status: :in_queue}} = socket
      ) do
    channel = Outcry.Matchmaker.channel()
    :ok = MatchmakingPresence.untrack(self(), channel, socket.assigns.user_id)

    {:noreply, socket |> assign(status: :in_game, game_pid: game_pid, state: %{})}
  end

  @impl true
  def handle_info(%{event: "state_update", state: state}, socket) do
    {:noreply, socket |> assign(state: state)}
  end

  @impl true
  def handle_info(%{event: "game_over", score_info: score_info}, socket) do
    {:noreply, socket |> assign(status: :game_over, score_info: score_info)}
  end

  defp error_for(element, message) do
    {:error, [{element, {message, []}}]}
  end

  @trades_per_second 4
  defp rate_limit(socket) do
    case ExRated.check_rate(socket.assigns.user_id, 1_000, @trades_per_second) do
      {:error, _} -> error_for("submit", "trading too fast, wait one second.")
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

  defp order_to_struct(order) do
    alias Outcry.Game.Orders.{Limit, Market, Cancel}

    case Map.get(order, "type") do
      "limit" -> Limit
      "market" -> Market
      "cancel" -> Cancel
      _ -> :error
    end
    |> case do
      :error ->
        error_for("order_type", "invalid order type.")

      m ->
        {:ok, to_struct(m, order)}
    end
  end

  @impl true
  def handle_event("order", %{"order" => order}, socket) do
    with {:ok, _} <- rate_limit(socket),
         {:ok, order} <- order_to_struct(order),
         :ok <- Outcry.Game.Player.place_order(self(), socket.assigns.game_pid, order) do
      :ok
    end
    |> case do
      :ok ->
        {:noreply, socket |> assign(errors: [])}

      {:error, error_messages} ->
        {:noreply, socket |> assign(errors: error_messages)}
    end
  end

  @impl true
  def render(%{status: :in_queue} = assigns) do
    ~L"""
      <h1>Looking for game...</h1>
    """
  end

  @impl true
  def render(%{status: :in_game} = assigns) do
    ~L"""
      <%= if @state != %{} do %>
        <%= for {_, player} <- @state.players do %>
          <div class="player_statistics">
          <div class="wealth"><%= player.wealth %> points</div>
          </div>
        <% end %>
        <div class="my_hand"><%= inspect @state.players[self()].hand, pretty: true %></div>
        <div class="order_book">
          <table>
            <thead>
            <th>Buy</th>
            <th>Suit</th>
            <th>Sell</th>
            </thead>
            <tbody>
            <%= for {suit, order_book} <- @state.order_books do %>
            <tr id="order-book-<%= suit %>">
              <%= for side <- [:buy, :sell] do %>
              <td>
                <% order_book_side = if(side == :buy, do: Enum.reverse(order_book.buy),
                                                      else: order_book.sell) %>
                <%= for {player, price} <- order_book_side do %>
                  <% nice_id = @state.players[player].nice_id %>
                  <% e_id = Enum.join(["order-book-order", nice_id, suit, side, price], "-") %>
                  <span class="order-book-order" id="<%= e_id %>" phx-hook="Order">
                  <%= price %><sup><%= nice_id %></sup>
                  </span>
                <% end %>
                <%= if side == :buy do %>
                <td><%= suit %></td>
                <% end %>
              </td>
              <% end %>
              </td>
            </tr>
            <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
      <%= f = form_for :order, "#", [phx_submit: :order, id: "order"] %>
      <%= label f, :direction, "Direction" %>
      <%= radio_button f, :direction, "buy", [required: true] %>  <%= label f, :direction_buy, "buy (a)" %>
      <%= radio_button f, :direction, "sell", [required: true] %> <%= label f, :direction_sell, "sell (s)" %>
      <br>
      <%= label f, :suit, "Suit" %>
      <%= select f, :suit, ["", "h", "j", "k", "l"], [required: true] %>
      <br>
      <%= label f, :price, "Price" %>
      <%= number_input f, :price, [min: 0, max: 200] %>
      <br>
      <%= radio_button f, :type, :limit, [checked: true] %>
      <%= label f, :type_limit, "Limit order (z)" %>
      <%= radio_button f, :type, :market %>
      <%= label f, :type_market, "Market order (x)" %>
      <%= radio_button f, :type, :cancel %>
      <%= label f, :type_cancel, "Cancel (c)" %>
      <br>
      <%= submit "Submit", [phx_disable_with: "Sending...", id: "order_submit"] %>
      <%= inspect Map.get(assigns, :errors) %>
      </form>
    """
  end

  @impl true
  def render(%{status: :game_over} = assigns) do
    ~L"""
    <h1>Game finished!</h1>

    <pre><%= inspect assigns.score_info, pretty: true %></pre>
    """
  end
end
