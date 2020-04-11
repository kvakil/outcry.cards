defmodule Outcry.RoomSupervisor do
  use DynamicSupervisor

  def start_link([]) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def start_child(%{name: name}) do
    DynamicSupervisor.start_child(__MODULE__, {Outcry.Room, %{name: name})
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
