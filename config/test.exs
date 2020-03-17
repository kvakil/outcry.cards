use Mix.Config

# Configure your database
config :outcry, Outcry.Repo,
  username: "postgres",
  password: "postgres",
  database: "outcry_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :outcry, OutcryWeb.Endpoint,
  http: [port: 4002],
  server: true

# Print only warnings and errors during test
config :logger, level: :warn

config :hound, driver: "phantomjs", port: 8910
