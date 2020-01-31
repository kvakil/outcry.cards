defmodule Outcry.Repo.Migrations.AddUserRating do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :rating, :float
    end
  end
end
