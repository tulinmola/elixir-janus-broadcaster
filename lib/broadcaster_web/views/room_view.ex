defmodule BroadcasterWeb.RoomView do
  use BroadcasterWeb, :view

  def render("room.json", %{room: room}) do
    %{
      id: room.id
    }
  end
end
