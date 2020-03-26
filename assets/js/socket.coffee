import {Socket} from "phoenix"

socket = new Socket("/socket", {params: {token: window.userToken}})

socket.onOpen (response) ->  console.log("Socket opened", response)
socket.onClose () -> console.warn("Socket closed")
socket.onError (error) -> console.error("Socket error", error)

socket.connect()

export default socket
