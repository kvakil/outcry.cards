defmodule OutcryWeb.OutcryLive do
  use Phoenix.LiveView

  def mount(_session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~L"""
    <h1>LiveView is awesome!</h1>
    """
  end
end
