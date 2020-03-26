defmodule BroadcasterWeb.RoomController do
  use BroadcasterWeb, :controller

  @type conn :: Plug.Conn.t()

  @spec index(conn, map) :: conn
  def index(conn, _params) do
    rooms = Broadcaster.list_rooms()
    render(conn, "index.html", rooms: rooms)
  end

  @spec new(conn, map) :: conn
  def new(conn, _params) do
    render(conn, "new.html")
  end

  @spec create(conn, map) :: conn
  def create(conn, %{"room" => room_params}) do
    case Broadcaster.create_room(room_params) do
      {:ok, room} ->
        conn
        |> put_flash(:info, "Room created successfully.")
        |> redirect(to: Routes.room_path(conn, :show, room))

      {:error, error} ->
        conn
        |> put_flash(:error, inspect(error))
        |> render("new.html")
    end
  end

  @spec show(conn, map) :: conn
  def show(conn, %{"id" => id}) do
    room = Broadcaster.get_room!(id)
    render(conn, "show.html", room: room)
  end

  @spec delete(conn, map) :: conn
  def delete(conn, %{"id" => id}) do
    with {:ok, _room} <- Broadcaster.delete_room(id) do
      conn
      |> put_flash(:info, "Room deleted successfully.")
      |> redirect(to: Routes.room_path(conn, :index))
    end
  end
end
