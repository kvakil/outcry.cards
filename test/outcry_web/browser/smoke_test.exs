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

  test "matchmaking works" do
    users = Enum.map(1..4, fn i ->
      {:ok, user} = Wallaby.start_session()
      user
      |> visit("/play")
      |> assert_has(Query.css(".title"))
      |> assert_text("Looking for game...")
      user
    end)

    Process.sleep(1000)
    users |> List.first() |> refute_has(Query.css(".title"))
  end
end
