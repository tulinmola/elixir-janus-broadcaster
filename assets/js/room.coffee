CONFIG =
  audio: true
  video: true
  iceServers: [
    {urls: "stun:stun.l.google.com:19302"}
  ]

register = (el) ->
  $el = $(el)
  id = $el.data("room")

  localVideo = $("#local-video").get(0)
  remoteVideo = $("#remote-video").get(0)

  socket = require("./socket").default

  topic = "room:#{id}"
  payload = {}
  channel = socket.channel(topic, payload)
  channel.join()
    .receive("ok", onJoin)
    .receive("error", onChannelError)

  onIceCandidate = ({candidate}) ->
    return unless candidate
    channel.push("trickle", {candidate})
      .receive("error", console.error)

  onTrack = ({streams: [stream]}) ->
    remoteVideo.srcObject = stream

  startBroadcast = ->
    console.log "startBroadcast"

    peerConnection = new RTCPeerConnection(CONFIG)
    peerConnection.onicecandidate = onIceCandidate
    peerConnection.ontrack = onTrack

    navigator.mediaDevices.getUserMedia(CONFIG).then (stream) ->
      localVideo.srcObject = stream
      peerConnection.addStream(stream)

      peerConnection.createOffer()
        .then (offer) ->
          peerConnection.setLocalDescription(offer)
          channel.push("publish", {offer})
            .receive("error", console.error)
        .catch(console.error)

    channel.on "answer", (answer) ->
      console.log "onAnswer", answer
      peerConnection.setRemoteDescription(new RTCSessionDescription(answer))

  joinBroadcast = ->
    console.log "joinBroadcast"

    peerConnection = new RTCPeerConnection(CONFIG)
    peerConnection.onicecandidate = onIceCandidate
    peerConnection.ontrack = onTrack

    channel.push("join-subscriber", {})
      .receive("error", console.error)

    channel.on "offer", (offer) ->
      console.log "onOffer", offer
      peerConnection.setRemoteDescription(new RTCSessionDescription(offer))
      peerConnection.createAnswer()
        .then (answer) ->
          peerConnection.setLocalDescription(answer)
          channel.push("listen", {answer})
            .receive("error", console.error)
        .catch(console.error)

  $("#join-publisher").click ->
    channel.push("join-publisher", {})
      .receive("ok", startBroadcast)
      .receive("error", console.error)

  $("#join-subscriber").click(joinBroadcast)

onJoin = (response) ->
  console.log(response)

onChannelError = (error) ->
  console.error(error)

$ ->
  $("[data-room]").each (_index, el) -> register(el)
  
