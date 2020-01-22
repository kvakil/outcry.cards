defmodule Outcry.Game.TypesTest do
  use ExUnit.Case, async: true
  alias Outcry.Game.Types.{Suit, Direction, Price}

  def assert_is_involution(f, x) do
    assert x != f.(x)
    assert x == f.(f.(x))
  end

  test "opposite suits" do
    import Suit
    for suit <- all_suits() do
      assert_is_involution(&opposite_suit/1, suit)
    end
  end

  test "opposite direction" do
    import Direction
    for direction <- all_directions() do
      assert_is_involution(&opposite_direction/1, direction)
    end
  end

  test "directions are inverses" do
    import Direction
    for direction <- all_directions() do
      assert direction_to_int(direction) == -direction_to_int(opposite_direction(direction))
    end
  end

  test "good suits accepted" do
    import Suit
    for suit <- all_suits() do
      assert {:ok, ^suit} = cast(suit)
      suit_string = Atom.to_string(suit)
      assert {:ok, ^suit} = cast(suit_string)
    end
  end

  test "bad suits denied" do
    import Suit
    assert {:error, _} = cast(:hello)
    assert {:error, _} = cast("hello")
    assert {:error, _} = cast("")
  end

  test "good directions accepted" do
    import Direction
    for direction <- all_directions() do
      assert {:ok, ^direction} = cast(direction)
      direction_string = Atom.to_string(direction)
      assert {:ok, ^direction} = cast(direction_string)
    end
  end

  test "bad directions denied" do
    import Direction
    assert {:error, _} = cast(:hello)
    assert {:error, _} = cast("hello")
    assert {:error, _} = cast("")
  end

  test "good prices allowed" do
    import Price
    assert {:ok, 10} = cast(10)
    assert {:ok, 10} = cast("10")
    assert {:ok, 0} = cast("0")
    assert {:ok, 200} = cast("200")
  end

  test "bad prices denied" do
    import Price
    assert {:error, message: "must be between 0 and 200."} = cast(-5)
    assert {:error, message: "must be between 0 and 200."} = cast(1000)
    assert {:error, message: "is not a number."} = cast("foo")
    assert {:error, message: "is not a number."} = cast("")
  end
end
