defmodule OutcryWeb.PageControllerTest do
  use OutcryWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Outcry"
  end
end
