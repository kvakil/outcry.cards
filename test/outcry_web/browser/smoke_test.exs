defmodule OutcryWeb.Browser.SmokeTest do
  use OutcryWeb.BrowserCase, async: true

  @register_button Query.link("Register", count: 2) |> Query.at(0)
  test "registration link works", %{session: session} do
    assert session
          |> visit("/")
          |> click(@register_button)
          |> current_url()
          |> String.ends_with?("/registration/new")
    session |> visit("/")
  end

  @play_button Query.link("Play as Guest", count: 2) |> Query.at(0)
  test "play button works", %{session: session} do
    assert session
          |> visit("/")
          |> click(@play_button)
          |> current_url()
          |> String.ends_with?("/play")
    session |> visit("/")
  end

  @looking_for_game Query.css(".title", text: "Looking for game...")
  @submit_button Query.css("#order_submit")
  @order_book_order Query.css(".order-book-order")
  test "basic game works" do
    users =
      Enum.map(1..4, fn i ->
        {:ok, user} = Wallaby.start_session()

        user |> visit("/play")

        if i != 4 do
          user |> assert_has(@looking_for_game)
        end

        user
      end)

    all_have = fn query ->
      Enum.each(users, fn user ->
        user |> assert_has(query)
      end)
    end

    all_have.(@submit_button)

    [first_user, second_user | _] = users
    first_user
    |> send_keys(["aj5", :enter])

    all_have.(@order_book_order)
  end
end
