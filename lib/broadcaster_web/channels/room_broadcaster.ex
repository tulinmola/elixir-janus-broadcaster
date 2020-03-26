defmodule BroadcasterWeb.RoomBroadcaster do
  alias BroadcasterWeb.{Endpoint, RoomView}

  @type room :: Broadcaster.Room.t()

  @lobby_topic "room:lobby"

  @spec broadcast_room!(room) :: :ok
  def broadcast_room!(room) do
    message = RoomView.render("room.json", %{room: room})
    :ok = Endpoint.broadcast(@lobby_topic, "room", message)
  end
end
