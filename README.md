# Outcry

To start your Phoenix server:

  * Install Elixir (v1.10+) using [these instructions](https://elixir-lang.org/install.html). 
  * Install dependencies with `mix deps.get`
  * Install `postgresql`, create a database `outcry_dev` and a user `postgres` and password `postgres`.
  * Create and migrate your database with `mix ecto.setup`
  * Install Node.js dependencies with `cd assets && npm install`
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Production

To run in production, run `docker-compose up`.
A copy running in production is occasionally available at <https://outcry.cards>.
