defmodule Broadcaster.RoomServer do
  use GenServer, restart: :transient

  alias Broadcaster.{Janus, Room, RoomServer}

  @type room :: Room.t()

  @type t :: %RoomServer{
          room: room,
          publisher_id: integer | nil,
          client: pid,
          client_room_id: integer | nil
        }

  defstruct [:room, :publisher_id, :client, :client_room_id]

  @client_timeout 5_000
  @ack_timeout 5_000

  @spec start_link(keyword) :: {:ok, pid} | {:error, any} | :ignore
  def start_link(opts) do
    room_id = Keyword.get(opts, :room_id)
    GenServer.start_link(RoomServer, room_id, opts)
  end

  @spec room(pid) :: room
  def room(pid) do
    GenServer.call(pid, :room)
  end

  @spec client_state(pid) :: room
  def client_state(pid) do
    GenServer.call(pid, :client_state)
  end

  @spec create_session(pid) :: {:ok, integer} | {:error, any}
  def create_session(pid) do
    GenServer.call(pid, :create_session)
  end

  @spec create_handle(pid, integer) :: {:ok, integer} | {:error, any}
  def create_handle(pid, session_id) do
    GenServer.call(pid, {:create_handle, session_id})
  end

  @spec ensure_room(pid, integer, integer) :: {:ok, integer} | {:error, any}
  def ensure_room(pid, session_id, handle_id) do
    GenServer.call(pid, {:ensure_room, session_id, handle_id})
  end

  @spec join_publisher(pid, integer, integer, pid) :: :ok | {:error, :timeout}
  def join_publisher(pid, session_id, handle_id, sender) do
    GenServer.call(pid, {:join_publisher, session_id, handle_id, sender})
  end

  @spec publish(pid, integer, integer, binary, pid) :: :ok | {:error, :timeout}
  def publish(pid, session_id, handle_id, offer, sender) do
    GenServer.call(pid, {:publish, session_id, handle_id, offer, sender})
  end

  @spec join_subscriber(pid, integer, integer, pid) :: :ok | {:error, :timeout}
  def join_subscriber(pid, session_id, handle_id, sender) do
    GenServer.call(pid, {:join_subscriber, session_id, handle_id, sender})
  end

  @spec listen(pid, integer, integer, binary, pid) :: :ok | {:error, :timeout}
  def listen(pid, session_id, handle_id, answer, sender) do
    GenServer.call(pid, {:listen, session_id, handle_id, answer, sender})
  end

  @spec trickle(pid, integer, integer, binary) :: :ok | {:error, :timeout}
  def trickle(pid, session_id, handle_id, candidate) do
    GenServer.call(pid, {:trickle, session_id, handle_id, candidate})
  end

  @spec keep_alive(pid, integer) :: :ok
  def keep_alive(pid, session_id) do
    GenServer.call(pid, {:keep_alive, session_id})
  end

  @spec kill(pid) :: :ok
  def kill(pid) do
    GenServer.call(pid, :kill)
  end

  @impl true
  @spec init(binary) :: {:ok, t}
  def init(id) do
    {:ok, client} = Janus.start_link(from: self())
    # TODO monitor client process?

    topic = "room:#{id}"
    room = %Room{id: id, topic: topic}

    {:ok, %RoomServer{room: room, publisher_id: nil, client: client, client_room_id: nil}}
  end

  @impl true
  def handle_call(:room, _from, state) do
    {:reply, state.room, state}
  end

  def handle_call(:client_state, _from, state) do
    {:reply, :sys.get_state(state.client), state}
  end

  def handle_call(:create_session, _from, state) do
    Janus.create_session(state.client)

    receive do
      {:session, session_id} -> {:reply, {:ok, session_id}, state}
    after
      @client_timeout -> {:error, :timeout}
    end
  end

  def handle_call({:create_handle, session_id}, _from, state) do
    Janus.create_handle(state.client, session_id)

    receive do
      {:handle, handle_id} -> {:reply, {:ok, handle_id}, state}
    after
      @client_timeout -> {:error, :timeout}
    end
  end

  def handle_call({:ensure_room, session_id, handle_id}, _from, %{client_room_id: nil} = state) do
    Janus.create_room(state.client, session_id, handle_id)

    receive do
      {:room, room_id} -> {:reply, {:ok, room_id}, %{state | client_room_id: room_id}}
    after
      @client_timeout -> {:error, :timeout}
    end
  end

  def handle_call({:ensure_room, _session_id, _handle_id}, _from, state) do
    {:reply, {:ok, state.client_room_id}, state}
  end

  def handle_call({:join_publisher, session_id, handle_id, sender}, _from, state) do
    Janus.join_publisher(state.client, session_id, handle_id, state.client_room_id, sender)
    wait_for_ack(:join_publisher, state)
  end

  def handle_call({:join_subscriber, session_id, handle_id, sender}, _from, state) do
    Janus.join_subscriber(state.client, session_id, handle_id, state.client_room_id, state.publisher_id, sender)
    wait_for_ack(:join_subscriber, state)
  end

  def handle_call({:trickle, session_id, handle_id, candidate}, _from, state) do
    Janus.trickle(state.client, session_id, handle_id, candidate)
    wait_for_ack(:trickle, state)
  end

  def handle_call({:publish, session_id, handle_id, offer, sender}, _from, state) do
    Janus.publish(state.client, session_id, handle_id, offer, sender)
    wait_for_ack(:publish, state)
  end

  def handle_call({:listen, session_id, handle_id, answer, sender}, _from, state) do
    Janus.listen(state.client, session_id, handle_id, answer, sender)
    wait_for_ack(:listen, state)
  end

  def handle_call({:keep_alive, session_id}, _from, state) do
    Janus.keep_alive(state.client, session_id)
    wait_for_ack(:keep_alive, state)
  end

  def handle_call(:kill, _from, state) do
    {:stop, :normal, :ok, state}
  end

  defp wait_for_ack(type, state) do
    receive do
      {^type, :ack} -> {:reply, :ok, state}
    after
      @ack_timeout -> {:reply, {:error, :timeout}, state}
    end
  end

  @impl true
  def handle_info({:publisher_id, id}, state) do
    IO.inspect({:publisher_id, id})
    {:noreply, %{state | publisher_id: id}}
  end

  # def handle_info({:answer, answer, pid}, state) do
  #   IO.inspect({:answer, answer, pid})
  #   send(pid, {:answer, answer})
  #   {:noreply, state}
  # end

  # def handle_info({:offer, offer, pid}, state) do
  #   IO.inspect({:offer, offer, pid})
  #   send(pid, {:offer, offer})
  #   {:noreply, state}
  # end

  # def handle_info(:keep_alive, state) do
  #   :ok = Janus.keep_alive(state.client)
  #   {:noreply, state}
  # end

  # def handle_info({:keep_alive, :ack}, state) do
  #   Process.send_after(self(), :keep_alive, @keep_alive_interval)
  #   {:noreply, state}
  # end

  def handle_info({:ack, transaction}, state) do
    IO.puts("Ignoring ACK: #{transaction}")
    {:noreply, state}
  end
end
