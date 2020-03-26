defmodule BroadcasterWeb.RoomChannel do
  use BroadcasterWeb, :channel

  alias BroadcasterWeb.RoomView

  @type topic :: binary
  @type event :: binary
  @type socket :: Phoenix.Socket.t()

  @keep_alive_interval 30_000

  @impl true
  @spec join(topic, map, socket) :: {:ok, map, socket}
  def join("room:" <> id, _payload, socket) do
    case Broadcaster.get_room(id) do
      {:ok, _pid, room} ->
        session_id = Broadcaster.create_session!(id)
        handle_id = Broadcaster.create_handle!(id, session_id)
        room_id = Broadcaster.ensure_room!(id, session_id, handle_id)

        socket =
          socket
          |> assign(:id, id)
          |> assign(:session_id, session_id)
          |> assign(:handle_id, handle_id)
          |> assign(:room_id, room_id)

        response = %{
          assigns: socket.assigns,  # TODO tmp
          room: render_room(room)
        }

        Process.send_after(self(), :keep_alive, @keep_alive_interval)

        {:ok, response, socket}

      {:error, :not_found} ->
        {:error, %{reason: "not_found"}}
    end
  end

  @impl true
  @spec handle_in(event, map, socket) ::
          {:noreply, socket} | {:reply, {:ok, map}, socket} | {:reply, {:error, map}, socket}
  def handle_in("join-publisher", _payload, socket) do
    IO.puts("join-publisher")

    socket.assigns.id
    |> Broadcaster.join_publisher!(socket.assigns.session_id, socket.assigns.handle_id, self())
    |> wrap_ack(socket)
  end

  def handle_in("join-subscriber", _params, socket) do
    IO.puts("join-subscriber")

    socket.assigns.id
    |> Broadcaster.join_subscriber!(socket.assigns.session_id, socket.assigns.handle_id, self())
    |> wrap_ack(socket)
  end

  def handle_in("publish", %{"offer" => offer}, socket) do
    IO.puts("publish, offer: #{inspect(offer)}")

    socket.assigns.id
    |> Broadcaster.publish!(socket.assigns.session_id, socket.assigns.handle_id, offer, self())
    |> wrap_ack(socket)
  end

  def handle_in("listen", %{"answer" => answer}, socket) do
    IO.puts("listen, answer: #{inspect(answer)}")

    socket.assigns.id
    |> Broadcaster.listen!(socket.assigns.session_id, socket.assigns.handle_id, answer, self())
    |> wrap_ack(socket)
  end

  def handle_in("trickle", %{"candidate" => candidate}, socket) do
    IO.puts("trickle, candidate: #{inspect(candidate)}")

    socket.assigns.id
    |> Broadcaster.trickle!(socket.assigns.session_id, socket.assigns.handle_id, candidate)
    |> wrap_ack(socket)
  end

  @impl true
  @spec handle_info(term, socket) :: {:noreply, socket}
  # def handle_info({:sender_id, sender_id}, socket) do
  #   {:noreply, assign(socket, :sender_id, sender_id)}
  # end

  def handle_info({:offer, offer}, socket) do
    push(socket, "offer", offer)
    {:noreply, socket}
  end

  def handle_info({:answer, answer}, socket) do
    push(socket, "answer", answer)
    {:noreply, socket}
  end

  def handle_info(:keep_alive, socket) do
    :ok = Broadcaster.keep_alive!(socket.assigns.id, socket.assigns.session_id)
    Process.send_after(self(), :keep_alive, @keep_alive_interval)
    {:noreply, socket}
  end

  defp wrap_ack(:ok, socket) do
    {:reply, {:ok, %{status: "ok"}}, socket}
  end

  defp wrap_ack({:error, error}, socket) do
    {:reply, {:error, %{status: error}}, socket}
  end

  defp render_room(room) do
    RoomView.render("room.json", %{room: room})
  end
end
