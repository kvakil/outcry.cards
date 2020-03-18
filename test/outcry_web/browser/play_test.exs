defmodule OutcryWeb.Hound.PlayTest do
  use ExUnit.Case
  use Hound.Helpers

  test "can queue for game" do
    Hound.start_session()
    navigate_to("/play")
    assert inner_text(find_element(:class, "title")) == "Looking for game..."
    Hound.end_session()
  end

  test "can matchmake game and play game" do
    for i <- 1..4 do
      change_session_to(i)
    end

    for i <- 1..4 do
      in_browser_session i, fn ->
        navigate_to("/play")
        if i == 4 do
          Process.sleep(1000)
          assert visible_page_text() =~ "Player"
        else
          assert inner_text(find_element(:class, "title")) == "Looking for game..."
        end
      end
    end

    in_browser_session 1, fn ->
      send_text("aj5")
      send_keys(:enter)
    end
    Process.sleep(5000)

    Hound.end_session()
  end
end
