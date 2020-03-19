defmodule OutcryWeb.BrowserCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      use Wallaby.DSL

      alias Outcry.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query

      import OutcryWeb.Router.Helpers
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Outcry.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Outcry.Repo, {:shared, self()})
    end

    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(Outcry.Repo, self())
    {:ok, session} = Wallaby.start_session(metadata: metadata)
    {:ok, session: session}
  end
end
