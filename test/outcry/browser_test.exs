defmodule HoundTest do
  use ExUnit.Case
  use Hound.Helpers

  hound_session()

  test "homepage loads", meta do
    navigate_to("http://localhost:4000/")

    assert page_title() == "Outcry: open outcry game"
  end
end
