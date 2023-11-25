import asyncdispatch, asynchttpserver, ws
import strformat
import logutils, msg, logic

var connections {.threadvar.}: seq[WebSocket]

proc cb(req: Request) {.async, gcsafe.} =
  if req.url.path == "/ws":
    log "New Connection apeared"
    try:
      var ws = await newWebSocket(req)
      log "id: ", ws.key
      connections.add ws
      await ws.send(initialMsg)
      while ws.readyState == Open:
        let packet = await ws.receiveStrPacket()
        log fmt"Received packet from {ws.key}: {packet}"
        let res = calc(ws.key, packet)

        for other in connections:
          if other.readyState == Open:
            asyncCheck other.send(packet)
            log fmt"send {other.key}."
    except WebSocketClosedError:
      log getCurrentExceptionMsg()
      log "Socket closed. "
    except WebSocketProtocolMismatchError:
      log "Socket tried to use an unknown protocol: ", getCurrentExceptionMsg()
    except WebSocketError:
      log "Unexpected socket error: ", getCurrentExceptionMsg()
  await req.respond(Http200, "Hello World")


when isMainModule:
  connections = newSeq[WebSocket]()
  setLogger()

  var server = newAsyncHttpServer()
  waitFor server.serve(Port(8000), cb)

