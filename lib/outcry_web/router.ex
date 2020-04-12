defmodule OutcryWeb.Router do
  use OutcryWeb, :router
  use Pow.Phoenix.Router
  use Pow.Extension.Phoenix.Router,
    extensions: [PowResetPassword, PowEmailConfirmation]

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :protected do
    plug Pow.Plug.RequireAuthenticated,
      error_handler: Pow.Phoenix.PlugErrorHandler
  end

  pipeline :pow_layout do
    plug :put_layout, {OutcryWeb.LayoutView, :pow}
  end

  scope "/" do
    pipe_through [:browser, :pow_layout]

    pow_routes()
    pow_extension_routes()
  end

  scope "/", OutcryWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  scope "/", OutcryWeb do
    pipe_through :browser

    live "/play", OutcryLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", OutcryWeb do
  #   pipe_through :api
  # end
end
