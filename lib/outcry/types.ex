defmodule Outcry.Game.Types do
  defmodule VirtualType do
    defmacro __using__(_) do
      quote do
        def load(_), do: :error
        def dump(_), do: :error
      end
    end
  end

  defmodule EnumType do
    defmacro __using__(valid) do
      quote do
        @all unquote(valid)

        def type, do: :string

        def cast(e) when is_binary(e) do
          # XXX: we might be tempted to implement the is_binary case in
          # terms of the is_atom case below. However this way ensures
          # that we do not allocate more atoms, preventing
          # denial-of-service.
          valid_strings = Map.new(@all, &{Atom.to_string(&1), &1})

          case Map.fetch(valid_strings, e) do
            :error ->
              error_message = "is not one of #{Enum.join(@all, ", ")}"
              {:error, message: error_message}

            ok ->
              ok
          end
        end

        def cast(e) when is_atom(e) do
          cast(Atom.to_string(e))
        end

        def cast(_), do: :error
      end
    end
  end

  defmodule Suit do
    use Ecto.Type
    use Outcry.Game.Types.EnumType, [:h, :j, :k, :l]
    use Outcry.Game.Types.VirtualType

    def opposite_suit(:h), do: :l
    def opposite_suit(:j), do: :k
    def opposite_suit(:k), do: :j
    def opposite_suit(:l), do: :h

    def all_suits, do: @all
  end

  defmodule Direction do
    use Ecto.Type
    use Outcry.Game.Types.EnumType, [:buy, :sell]
    use Outcry.Game.Types.VirtualType

    @buy_direction 1
    @sell_direction -1

    def opposite_direction(:buy), do: :sell
    def opposite_direction(:sell), do: :buy
    def direction_to_int(:buy), do: @buy_direction
    def direction_to_int(:sell), do: @sell_direction

    def all_directions, do: @all
  end

  defmodule Price do
    use Outcry.Game.Types.VirtualType

    def type, do: :integer

    def cast(price) when is_binary(price) do
      case Integer.parse(price) do
        {price, _} -> cast(price)
        :error -> {:error, message: "is not a number"}
      end
    end

    def cast(price) when is_integer(price) do
      if 0 <= price and price <= 200 do
        {:ok, price}
      else
        {:error, message: "must be between 0 and 200"}
      end
    end

    def cast(_), do: :error
  end
end
