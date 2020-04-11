defmodule Outcry.RoomTest do
  use ExUnit.Case, async: true
  alias Outcry.FakePlayer
  alias Outcry.RoomTracker

  setup do
    players =
      Enum.map(1..4, fn id ->
        %{pid: start_supervised!({FakePlayer, %{parent_pid: self()}}, id: id), user_id: id}
      end)

    %{players: players, random_room: Ecto.UUID.generate()}
  end

  test "rooms can be created", %{players: [player0 | _], random_room: room} do
    assert :ok = RoomTracker.create_room(player0 |> Map.put(:room, room))
  end

  test "rooms can't be created twice", %{players: [player0, player1 | _], random_room: room} do
    assert :ok = RoomTracker.create_room(player0 |> Map.put(:room, room))
    assert {:error, _} = RoomTracker.create_room(player1 |> Map.put(:room, room))
  end

  test "rooms can start games (easy)", %{players: [player0 | other_players] = all_players, random_room: room} do
    assert :ok = RoomTracker.create_room(player0 |> Map.put(:room, room))
    Enum.each(other_players, fn other_player ->
      assert :ok = RoomTracker.join_room(other_player |> Map.put(:room, room))
    end)
    assert :ok = RoomTracker.start_room(player0 |> Map.put(:room, room))
    Enum.each(all_players, fn %{pid: pid} ->
      assert_receive {^pid, %{event: "game_start"}}
    end)
  end

  test "rooms can start games (hard)", %{players: [player0, player1 | other_players] = all_players, random_room: room} do
    assert :ok = RoomTracker.create_room(player0 |> Map.put(:room, room))
    Enum.each([player1 | other_players], fn other_player ->
      assert :ok = RoomTracker.join_room(other_player |> Map.put(:room, room))
    end)
    assert :ok = RoomTracker.leave_room(player0 |> Map.put(:room, room))
    assert {:error, _} = RoomTracker.start_room(player1 |> Map.put(:room, room))
    assert :ok = RoomTracker.join_room(player0 |> Map.put(:room, room))
    assert :ok = RoomTracker.start_room(player0 |> Map.put(:room, room))
    Enum.each(all_players, fn %{pid: pid} ->
      assert_receive {^pid, %{event: "game_start"}}
    end)
  end
end
