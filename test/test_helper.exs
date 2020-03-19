Application.put_env(:wallaby, :screenshot_on_failure, true)
{:ok, _} = Application.ensure_all_started(:wallaby)
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Outcry.Repo, :manual)
