defmodule Outcry.Game.Orders do
  defmodule VirtualChangeset do
    defmacro __using__(schema) do
      # TODO: how to ensure schema is only evaluated once
      quote do
        import Ecto.Changeset

        defstruct Keyword.keys(unquote(schema))

        defp validate(changeset) do
          changeset |> validate_required(Keyword.keys(unquote(schema)))
        end

        defoverridable validate: 1

        def changeset(%__MODULE__{} = params) do
          params
          |> cast()
          |> validate()
          |> apply_action(:insert)
        end

        defp cast(params) do
          schema_keys = Keyword.keys(unquote(schema))

          Ecto.Changeset.cast(
            {struct(__MODULE__), Map.new(unquote(schema))},
            Map.from_struct(params),
            schema_keys
          )
        end
      end
    end
  end

  defmodule Limit do
    alias Outcry.Game
    use Game.Orders.VirtualChangeset,
      suit: Game.Types.Suit,
      direction: Game.Types.Direction,
      price: Game.Types.Price
  end

  defmodule Market do
    alias Outcry.Game
    use Game.Orders.VirtualChangeset,
      suit: Game.Types.Suit,
      direction: Game.Types.Direction
  end

  defmodule Cancel do
    alias Outcry.Game
    use Game.Orders.VirtualChangeset,
      suit: Game.Types.Suit,
      direction: Game.Types.Direction
  end
end
