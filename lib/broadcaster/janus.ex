defmodule Broadcaster.Janus do
  use WebSockex

  alias Broadcaster.Janus

  defmodule Transaction do
    @type type ::
            :create_session
            | :create_handle
            | :create_room
            | :join_publisher
            | :join_subscriber
            | :publish
            | :listen
            | :trickle
            | :keep_alive

    @type t :: %Transaction{
            type: type,
            sender: pid | nil
          }
    defstruct [:type, :sender]
  end

  @type transaction :: Transaction.t()

  @type t :: %Janus{
          from: pid,
          session_id: integer | nil,
          handle_id: integer | nil,
          senders: map,
          transactions: map
        }

  defstruct [:from, :session_id, :handle_id, :senders, :transactions]

  # @url "ws://localhost:8188"
  @url "wss://s1.cvpsi.com:8989"
  @extra_headers [{"Sec-WebSocket-Protocol", "janus-protocol"}]

  @spec start_link(any) :: {:ok, pid} | {:error, pid}
  def start_link(opts) do
    opts = Keyword.merge([extra_headers: @extra_headers], opts)
    from = opts[:from]

    WebSockex.start_link(
      @url,
      __MODULE__,
      %Janus{from: from, senders: %{}, transactions: %{}},
      opts
    )
  end

  @spec create_session(pid) :: :ok
  def create_session(pid) do
    send_message(pid, :create_session, %{
      janus: "create"
    })
  end

  @spec create_handle(pid, integer) :: :ok
  def create_handle(pid, session_id) do
    send_message(pid, :create_handle, %{
      session_id: session_id,
      janus: "attach",
      plugin: "janus.plugin.videoroom"
    })
  end

  @spec create_room(pid, integer, integer) :: :ok
  def create_room(pid, session_id, handle_id) do
    send_message(pid, :create_room, %{
      janus: "message",
      session_id: session_id,
      handle_id: handle_id,
      body: %{
        request: "create"
      }
    })
  end

  @spec join_publisher(pid, integer, integer, integer, pid) :: :ok
  def join_publisher(pid, session_id, handle_id, room_id, sender) do
    send_message(
      pid,
      :join_publisher,
      %{
        janus: "message",
        session_id: session_id,
        handle_id: handle_id,
        room_id: room_id,
        body: %{
          request: "join",
          ptype: "publisher",
          room: room_id
        }
      },
      sender
    )
  end

  @spec join_subscriber(pid, integer, integer, integer, integer, pid) :: :ok
  def join_subscriber(pid, session_id, handle_id, room_id, feed_id, sender) do
    send_message(
      pid,
      :join_subscriber,
      %{
        janus: "message",
        session_id: session_id,
        handle_id: handle_id,
        room_id: room_id,
        feed_id: feed_id,
        body: %{
          request: "join",
          ptype: "subscriber",
          room: room_id,
          feed: feed_id
        }
      },
      sender
    )
  end

  @spec publish(pid, integer, integer, binary, pid) :: :ok
  def publish(pid, session_id, handle_id, offer, sender) do
    send_message(
      pid,
      :publish,
      %{
        janus: "message",
        session_id: session_id,
        handle_id: handle_id,
        body: %{
          request: "publish"
        },
        jsep: offer
      },
      sender
    )
  end

  @spec listen(pid, integer, integer, binary, pid) :: :ok
  def listen(pid, session_id, handle_id, answer, sender) do
    send_message(
      pid,
      :listen,
      %{
        janus: "message",
        session_id: session_id,
        handle_id: handle_id,
        body: %{
          request: "start"
        },
        jsep: answer
      },
      sender
    )
  end

  @spec trickle(pid, integer, integer, binary) :: :ok
  def trickle(pid, session_id, handle_id, candidate) do
    send_message(pid, :trickle, %{
      janus: "trickle",
      session_id: session_id,
      handle_id: handle_id,
      candidate: candidate
    })
  end

  @spec keep_alive(pid, integer) :: :ok
  def keep_alive(pid, session_id) do
    send_message(pid, :keep_alive, %{
      janus: "keepalive",
      session_id: session_id
    })
  end

  defp send_message(pid, type, message, sender \\ nil) do
    uuid = UUID.uuid4()
    message = Map.put(message, :transaction, uuid)
    WebSockex.cast(pid, {:send_message, message, type, sender})
  end

  @impl true
  def handle_frame({:text, text}, state) do
    message = Jason.decode!(text) |> IO.inspect()

    transaction = Map.get(message, "transaction")
    case Map.get(state.transactions, transaction) do
      %{sender: sender, type: type} ->
        {:ok, handle_message(type, message, transaction, sender, state)}

      _ ->
        IO.puts "Ignoring transaction #{transaction}"
        {:ok, state}
    end
  end

  defp handle_message(:create_session, %{"data" => %{"id" => id}}, transaction, _sender, state) do
    send(state.from, {:session, id})

    state
    |> update_session_id(id)
    |> delete_transaction(transaction)
  end

  defp handle_message(:create_handle, %{"data" => %{"id" => id}}, transaction, _sender, state) do
    send(state.from, {:handle, id})

    state
    |> update_handle_id(id)
    |> delete_transaction(transaction)
  end

  defp handle_message(
         :create_room,
         %{"plugindata" => %{"data" => %{"room" => id}}},
         transaction,
         _sender,
         state
       ) do
    send(state.from, {:room, id})
    delete_transaction(state, transaction)
  end

  defp handle_message(:join_publisher, %{"janus" => "ack"}, _transaction, _sender, state) do
    send(state.from, {:join_publisher, :ack})
    state
  end

  defp handle_message(
         :join_publisher,
         %{"plugindata" => %{"data" => %{"id" => publisher_id}}, "sender" => sender_id},
         transaction,
         sender,
         state
       ) do
    send(state.from, {:publisher_id, publisher_id})

    state
    |> update_sender(sender_id, sender)
    |> delete_transaction(transaction)
  end

  defp handle_message(:join_subscriber, %{"janus" => "ack"}, _transaction, _sender, state) do
    send(state.from, {:join_subscriber, :ack})
    state
  end

  defp handle_message(
         :join_subscriber,
         %{"jsep" => offer, "sender" => sender_id},
         transaction,
         sender,
         state
       ) do

    state
    |> update_sender(sender_id, sender)
    |> send_to_sender(sender_id, {:offer, offer})
    |> delete_transaction(transaction)
  end

  defp handle_message(:publish, %{"janus" => "ack"}, _transaction, _sender, state) do
    send(state.from, {:publish, :ack})
    state
  end

  defp handle_message(:publish, %{"jsep" => answer, "sender" => sender_id}, _transaction, _sender, state) do
    send_to_sender(state, sender_id, {:answer, answer})
  end

  defp handle_message(:listen, %{"janus" => "ack"}, _transaction, _sender, state) do
    send(state.from, {:listen, :ack})
    state
  end

  defp handle_message(:listen, _message, transaction, _sender, state) do
    delete_transaction(state, transaction)
  end

  defp handle_message(:trickle, %{"janus" => "ack"}, transaction, _sender, state) do
    send(state.from, {:trickle, :ack})
    delete_transaction(state, transaction)
  end

  defp handle_message(:keep_alive, %{"janus" => "ack"}, transaction, _sender, state) do
    send(state.from, {:keep_alive, :ack})
    delete_transaction(state, transaction)
  end

  defp handle_message(_type, message, _transaction, _sender, state) do
    IO.puts("IGNORING MESSAGE")
    IO.inspect(message)
    state
  end

  defp send_to_sender(state, sender_id, message) do
    state.senders
    |> Map.get(sender_id)
    |> send(message)
    # TODO what if sender doesn't exist? Remove from senders?

    state
  end

  defp update_session_id(state, id) do
    %{state | session_id: id}
  end

  defp update_handle_id(state, id) do
    %{state | handle_id: id}
  end

  defp update_sender(state, sender_id, sender) do
    %{state | senders: Map.put(state.senders, sender_id, sender)}
  end

  defp delete_transaction(state, transaction) do
    %{state | transactions: Map.delete(state.transactions, transaction)}
  end

  @impl true
  def handle_cast({:send_message, message, type, sender}, state) do
    key = Map.get(message, :transaction)

    transaction = %Transaction{
      type: type,
      sender: sender
    }

    transactions = Map.put(state.transactions, key, transaction)

    frame = {:text, Jason.encode!(message |> IO.inspect)}
    {:reply, frame, %Janus{state | transactions: transactions}}
  end

  def handle_cast({:send, {type, msg} = frame}, state) do
    IO.puts("Sending #{type} frame with payload: #{msg}")
    {:reply, frame, state}
  end

  @impl true
  def handle_info({:send, {type, msg}}, state) do
    IO.puts("Info #{type} frame with payload: #{msg}")
    {:ok, state}
  end

  # handle_disconnect, handle_ping, handle_pong, terminate, code_change, format_status,
end
