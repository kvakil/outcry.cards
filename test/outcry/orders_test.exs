defmodule Outcry.Game.OrdersTest do
  use ExUnit.Case, async: true
  alias Outcry.Game.Orders.{Limit, Market, Cancel}

  test "valid orders" do
    limit = %Limit{suit: :j, direction: :buy, price: 10}
    assert {:ok, ^limit} = Limit.changeset(limit)

    market = %Market{suit: :j, direction: :buy}
    assert {:ok, ^market} = Market.changeset(market)

    cancel = %Cancel{suit: :j, direction: :buy}
    assert {:ok, ^cancel} = Cancel.changeset(cancel)
  end

  test "bad orders (bad data)" do
    limit = %Limit{suit: :a, direction: :b, price: :c}
    assert {:error, errors} = Limit.changeset(limit)
    errors_as_map = Outcry.DataCase.errors_on(errors)
    assert %{suit: suit_error} = errors_as_map
    assert %{direction: direction_error} = errors_as_map
    assert %{price: [_]} = errors_as_map

    market = %Market{suit: :a, direction: :b}
    assert {:error, errors} = Market.changeset(market)
    errors_as_map = Outcry.DataCase.errors_on(errors)
    assert %{suit: ^suit_error} = errors_as_map
    assert %{direction: ^direction_error} = errors_as_map

    cancel = %Cancel{suit: :a, direction: :b}
    assert {:error, errors} = Cancel.changeset(cancel)
    errors_as_map = Outcry.DataCase.errors_on(errors)
    assert %{suit: ^suit_error} = errors_as_map
    assert %{direction: ^direction_error} = errors_as_map
  end

  test "bad orders (missing data)" do
    blank_error = ["can't be blank"]

    limit = %Limit{}
    assert {:error, errors} = Limit.changeset(limit)
    errors_as_map = Outcry.DataCase.errors_on(errors)
    assert %{suit: ^blank_error} = errors_as_map
    assert %{direction: ^blank_error} = errors_as_map
    assert %{price: ^blank_error} = errors_as_map

    market = %Market{}
    assert {:error, errors} = Market.changeset(market)
    errors_as_map = Outcry.DataCase.errors_on(errors)
    assert %{suit: ^blank_error} = errors_as_map
    assert %{direction: ^blank_error} = errors_as_map

    cancel = %Cancel{}
    assert {:error, errors} = Cancel.changeset(cancel)
    errors_as_map = Outcry.DataCase.errors_on(errors)
    assert %{suit: ^blank_error} = errors_as_map
    assert %{direction: ^blank_error} = errors_as_map
  end
end
