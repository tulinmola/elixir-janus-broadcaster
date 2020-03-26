defmodule Broadcaster.RoomRepo do
  alias Broadcaster.{Room, RoomRegistry, RoomServer, RoomSupervisor}

  @type room :: Room.t()

  @spec all :: [pid]
  def all, do: list_pids()

  @spec get(binary) :: pid | :undefined
  def get(id) do
    case Registry.lookup(RoomRegistry, id) do
      [{pid, _value}] -> pid
      _ -> :undefined
    end
  end

  @spec insert(integer) :: {:ok, pid} | {:error, any}
  def insert(id) do
    child_spec = {RoomServer, room_id: id, name: via_name(id)}

    case DynamicSupervisor.start_child(RoomSupervisor, child_spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, error} -> {:error, error}
    end
  end

  @spec delete(pid) :: :ok
  def delete(pid) do
    RoomServer.kill(pid)
  end

  @spec delete_all :: :ok
  def delete_all do
    list_pids()
    |> Enum.each(&RoomServer.kill/1)
  end

  defp via_name(id) do
    {:via, Registry, {RoomRegistry, id}}
  end

  defp list_pids do
    RoomSupervisor
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn {_id, child, _type, _modules} -> child end)
  end
end
