defmodule Broadcaster.Room do
  alias Broadcaster.Room

  @type t :: %Room{
          id: binary,
          topic: binary
        }

  defstruct [:id, :topic]
end
