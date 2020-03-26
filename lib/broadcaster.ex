defmodule Broadcaster do
  alias Broadcaster.{Room, RoomRepo, RoomServer}

  @type room :: Room.t()

  @spec list_rooms :: [room]
  def list_rooms do
    RoomRepo.all()
    |> Enum.map(&RoomServer.room/1)
  end

  @spec create_room(map) :: {:ok, room} | {:error, any}
  def create_room(attrs) do
    id = Map.get(attrs, "id")

    case RoomRepo.insert(id) do
      {:ok, pid} -> {:ok, RoomServer.room(pid)}
      {:error, error} -> {:error, error}
    end
  end

  @spec get_room(binary) :: {:ok, pid, room} | {:error, :not_found}
  def get_room(id) do
    case RoomRepo.get(id) do
      :undefined -> {:error, :not_found}
      pid -> {:ok, pid, RoomServer.room(pid)}
    end
  end

  @spec get_room!(binary) :: room
  def get_room!(id) do
    {:ok, _pid, room} = get_room(id)
    room
  end

  @spec delete_room(binary) :: {:ok, room} | {:error, any}
  def delete_room(id) do
    case get_room(id) do
      {:ok, pid, room} ->
        :ok = RoomServer.kill(pid)
        {:ok, room}

      {:error, error} ->
        {:error, error}
    end
  end

  @spec create_session!(binary) :: integer
  def create_session!(id) do
    {:ok, pid, _room} = get_room(id)
    {:ok, session_id} = RoomServer.create_session(pid)
    session_id
  end

  @spec create_handle!(binary, integer) :: integer
  def create_handle!(id, session_id) do
    {:ok, pid, _room} = get_room(id)
    {:ok, session_id} = RoomServer.create_handle(pid, session_id)
    session_id
  end

  @spec ensure_room!(binary, integer, integer) :: integer
  def ensure_room!(id, session_id, handle_id) do
    {:ok, pid, _room} = get_room(id)
    {:ok, room_id} = RoomServer.ensure_room(pid, session_id, handle_id)
    room_id
  end

  @spec join_publisher!(binary, integer, integer, pid) :: :ok | {:error, :timeout}
  def join_publisher!(id, session_id, handle_id, sender) do
    {:ok, pid, _room} = get_room(id)
    RoomServer.join_publisher(pid, session_id, handle_id, sender)
  end

  @spec publish!(binary, integer, integer, binary, pid) :: :ok | {:error, :timeout}
  def publish!(id, session_id, handle_id, offer, sender) do
    {:ok, pid, _room} = get_room(id)
    RoomServer.publish(pid, session_id, handle_id, offer, sender)
  end

  @spec join_subscriber!(binary, integer, integer, pid) :: :ok | {:error, :timeout}
  def join_subscriber!(id, session_id, handle_id, sender) do
    {:ok, pid, _room} = get_room(id)
    RoomServer.join_subscriber(pid, session_id, handle_id, sender)
  end

  @spec listen!(binary, integer, integer, binary, pid) :: :ok | {:error, :timeout}
  def listen!(id, session_id, handle_id, answer, sender) do
    {:ok, pid, _room} = get_room(id)
    RoomServer.listen(pid, session_id, handle_id, answer, sender)
  end

  @spec trickle!(binary, integer, integer, binary) :: :ok | {:error, :timeout}
  def trickle!(id, session_id, handle_id, candidate) do
    {:ok, pid, _room} = get_room(id)
    RoomServer.trickle(pid, session_id, handle_id, candidate)
  end

  @spec keep_alive!(binary, integer) :: :ok | {:error, :timeout}
  def keep_alive!(id, session_id) do
    {:ok, pid, _room} = get_room(id)
    RoomServer.keep_alive(pid, session_id)
  end
end
