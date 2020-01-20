defmodule Outcry.Repo do
  use Ecto.Repo,
    otp_app: :outcry,
    adapter: Ecto.Adapters.Postgres
end
