defmodule OutcryWeb.Browser.SmokeTest do
  use OutcryWeb.BrowserCase, async: true

  alias Wallaby.{Element, Query}

  @register_button Query.link("Register", count: 2) |> Query.at(0)
  test "registration link works", %{session: session} do
    assert session
           |> visit("/")
           |> click(@register_button)
           |> current_url()
           |> String.ends_with?("/registration/new")
  end

  @play_button Query.link("Play as Guest", count: 2) |> Query.at(0)
  test "play button works", %{session: session} do
    assert session
           |> visit("/")
           |> click(@play_button)
           |> current_url()
           |> String.ends_with?("/play")
  end

  @looking_for_game Query.css(".title", text: "Looking for game...")
  test "matchmaking works" do
    users =
      Stream.repeatedly(fn ->
        {:ok, user} = Wallaby.start_session()

        user
        |> visit("/play")
        |> assert_has(@looking_for_game)

        user
      end)
      |> Enum.take(4)

    Process.sleep(1000)
    Enum.each(users, fn user ->
      user |> refute_has(@looking_for_game)
    end)
  end
end
