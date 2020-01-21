# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :outcry,
  ecto_repos: [Outcry.Repo]

# Configures the endpoint
config :outcry, OutcryWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Np58CrqiXNN/0Y/r/qk1fKjek75oKsxjKxqoU0hVD+wQ65a9G23fbgFYOXx2w6yg",
  render_errors: [view: OutcryWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Outcry.PubSub, adapter: Phoenix.PubSub.PG2],
  live_view: [signing_salt: "m9TwLHqcv5wZMefDgAhYSQxRAhAuZ8BSD6+D4CBDNda95yOysMzXZiuPQlhQ/d5u"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
