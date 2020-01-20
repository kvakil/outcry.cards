defmodule OutcryWeb.PageController do
  use OutcryWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
