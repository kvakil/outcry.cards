defmodule Outcry.Users.User do
  use Ecto.Schema
  use Pow.Ecto.Schema

  use Pow.Extension.Ecto.Schema,
    extensions: [PowResetPassword, PowEmailConfirmation]

  schema "users" do
    field :rating, :float, default: 0.0
    pow_user_fields()
    timestamps()
  end

  def changeset(user_or_changeset, attrs) do
    user_or_changeset
    |> pow_changeset(attrs)
    |> pow_extension_changeset(attrs)
  end

  defp changeset_rating(user_or_changeset, attrs) do
    user_or_changeset
    |> Ecto.Changeset.cast(attrs, [:rating])
  end

  def update_rating(user, new_rating) do
    alias Outcry.Repo
    user
    |> changeset_rating(%{rating: new_rating})
    |> Repo.update()
  end
end
