FROM elixir:1.10.2 as build

# install build dependencies
RUN apt-get update && apt-get install -y nodejs npm

# prepare build dir
RUN mkdir /app
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV=prod

# install mix dependencies
COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get
RUN mix deps.compile

# build assets digest
COPY assets assets
RUN cd assets && npm install && npm run deploy
RUN mix phx.digest

# build project
COPY lib lib
RUN mix compile

# build release (uncomment COPY if rel/ exists)
RUN mix release

# prepare release image
FROM elixir:1.10.2 AS app

RUN mkdir /app
WORKDIR /app

COPY --from=build /app/_build/prod/rel/outcry ./
RUN chown -R nobody: /app
USER nobody

# set build ENV
ENV MIX_ENV=prod
ENV HOME=/app

# start script
COPY docker/outcry/start.sh .

CMD ["/app/start.sh"]
