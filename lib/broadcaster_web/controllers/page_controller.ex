defmodule BroadcasterWeb.PageController do
  use BroadcasterWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
