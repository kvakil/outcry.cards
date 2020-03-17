defmodule HoundTest do
  use ExUnit.Case
  use Hound.Helpers

  hound_session()

  test "homepage loads", _meta do
    navigate_to("http://example.com/")

    assert page_title() == "Outcry: open outcry game"
  end
end
