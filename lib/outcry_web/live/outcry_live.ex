defmodule OutcryWeb.OutcryLive do
  use Phoenix.{LiveView, HTML}
  alias OutcryWeb.MatchmakingPresence

  @impl true
  def mount(%{}, socket) do
    {:ok,
     socket
     |> assign(user_id: inspect(self()), status: :in_queue),
     temporary_assigns: [trade_message: nil]}
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
  def handle_info(%{event: "trade"} = trade_message, socket) do
    {:noreply, socket |> assign(trade_message: trade_message)}
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
        {:noreply, socket |> assign(errors: nil)}

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
      <div class="tile is-ancestor">
        <div class="tile is-parent is-vertical">
          <div class="tile is-parent">
            <div class="tile is-parent is-vertical is-3">
              <div class="tile is-child box">
                <table class="table is-bordered is-fullwidth">
                  <thead>
                  <th>Player</th>
                  <th>Points</th>
                  </thead>
                  <tbody>
                    <%= for {pid, player} <- @state.players do %>
                    <tr>
                      <td class="player" style="height: 44px;"><%= player.nice_id %>
                      <%= if self() == pid do %>
                        <abbr title="You are player <%= player.nice_id %>.">(*)</abbr>
                      <% end %>
                      </td>
                      <td class="wealth" style="height: 44px;"><%= player.wealth %></td>
                    </tr>
                    <% end %>
                </table>
              </div>
            </div>
            <div class="tile is-parent is-6" id="order_book">
              <div class="tile is-child box">
                <table class="table is-bordered is-fullwidth">
                  <thead>
                  <th style="text-align: right;">Buy</th>
                  <th>Suit</th>
                  <th>Sell</th>
                  </thead>
                  <tbody>
                  <% hand = @state.players[self()].hand %>
                  <%= for {suit, order_book} <- @state.order_books do %>
                  <tr id="order-book-<%= suit %>">
                    <%= for side <- [:buy, :sell] do %>
                    <td style="min-width: 10em; height: 44px;" class="order-book-<%= side %>">
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
                        <td class="has-text-centered">
                        <%= suit %>
                        <abbr title="You have <%= hand[suit] %> cards of suit <%= suit %>.">
                        (<%= hand[suit] %>)
                        </abbr>
                        </td>
                      <% end %>
                    </td>
                    <% end %>
                    </td>
                  </tr>
                  <% end %>
                  </tbody>
                </table>
              </div>
            </div>
            <div id="trade_history_container" class="tile is-parent is-3">
              <div class="tile is-child box">
                <p class="label">Trade History</p>
                <div id="trade_history" phx-update="append" style="height: 11rem; overflow-y: scroll;">
                <%= if @trade_message do %>
                  <% %{trade_id: trade_id, trade: {parties, cross}, order: %{suit: suit}} = @trade_message %>
                  <% buyer_nice = @state.players[parties.buy].nice_id %>
                  <% seller_nice = @state.players[parties.sell].nice_id %>
                  <p id="order_history_trade_<%= trade_id %>" style="font-family: monospace;" phx-hook="History">
                    <%= buyer_nice %>+<%= suit %> &amp; <%= seller_nice %>+<%= cross %>
                  </p>
                <% end %>
                </div>
              </div>
            </div>
          </div>
          <div class="tile is-parent">
            <div class="tile is-child is-3"></div>
            <div class="tile is-child is-6">
              <%= f = form_for :order, "#", [phx_submit: :order, id: "order"] %>
              <div class="field is-horizontal">
                <div class="field-label">
                  <%= label f, :direction, "Direction", [class: "label"] %>
                </div>
                <div class="field-body is-narrow">
                  <div class="field">
                    <label class="radio">
                      <%= radio_button f, :direction, "buy", [required: true] %>
                      buy (<kbd>a</kbd>)
                    </label>
                    <label class="radio">
                      <%= radio_button f, :direction, "sell", [required: true] %>
                      sell (<kbd>s</kbd>)
                    </label>
                  </div>
                </div>
              </div>
              <div class="field is-horizontal">
                <div class="field-label is-normal">
                  <%= label f, :suit, "Suit", [class: "label"] %>
                </div>
                <div class="field-body is-narrow">
                  <div class="select">
                    <%= select f, :suit, ["", "h", "j", "k", "l"], [required: true] %>
                  </div>
                </div>
              </div>
              <div class="field is-horizontal">
                <div class="field-label is-normal">
                  <%= label f, :price, "Price", [class: "label"] %>
                </div>
                <div class="field-body">
                  <%= number_input f, :price, [min: 0, max: 200, class: "input", required: "", placeholder: "(use number keys)"] %>
                </div>
              </div>
              <div class="field is-horizontal">
                <div class="field-label">
                  <label class="label">Type</label>
                </div>
                <div class="field-body is-narrow">
                  <div class="field">
                    <label class="radio">
                      <%= radio_button f, :type, :limit, [checked: ""] %>
                      Limit (<kbd>z</kbd>)
                    </label>
                    <label class="radio">
                      <%= radio_button f, :type, :market %>
                      Market (<kbd>x</kbd>)
                    </label>
                    <label class="radio">
                      <%= radio_button f, :type, :cancel %>
                      Cancel (<kbd>c</kbd>)
                    </label>
                  </div>
                </div>
              </div>
              <div class="field is-horizontal">
                <div class="field-label is-normal"></div>
                <div class="field-body">
                  <div class="control">
                    <%= submit "Submit (Enter)", [id: "order_submit", class: "button is-link"] %>
                  </div>
                  <%= if Map.get(assigns, :errors) do %>
                  <p class="help is-danger">
                    <%= inspect @errors %>
                  </p>
                  <% end %>
                </div>
              </div>
              </form>
            </div>
            <div class="tile is-child is-3"></div>
          </div>
        </div>
      </div>
      <% end %>
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
