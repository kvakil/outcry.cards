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
  http: [port: 4001],
  server: true

# Print only warnings and errors during test
config :logger, level: :warn

Application.put_env(:wallaby, :base_url, "http://localhost:4001/")
# TODO: this works only on my local machine
config :wallaby,
  driver: Wallaby.Experimental.Chrome,
  chromedriver: "/mnt/c/ProgramData/chocolatey/bin/chromedriver.exe",
  screenshot_on_failure: true
