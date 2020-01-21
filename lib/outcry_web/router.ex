defmodule OutcryWeb.Router do
  use OutcryWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug Phoenix.LiveView.Flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", OutcryWeb do
    pipe_through :browser

    get "/", PageController, :index

    live "/play", OutcryLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", OutcryWeb do
  #   pipe_through :api
  # end
end
