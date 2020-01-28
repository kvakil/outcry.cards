defmodule OutcryWeb.PageController do
  use OutcryWeb, :controller
  plug :put_layout, "base.html"

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def help(conn, _params) do
    render(conn, "help.html")
  end

  def tips(conn, _params) do
    render(conn, "tips.html")
  end
end
