import asyncdispatch, asynchttpserver, ws
import strformat, json, sequtils
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
        let reslist = calc(ws.key, packet)
        for res in reslist:
          case res.dst:
          of sdAll:
            for other in connections:
              if other.readyState == Open:
                asyncCheck other.send($(%* {"kind": $res.kind, "data": res.data}))
                log fmt"send {other.key}."
          of sdAnswerer:
            let idlist = getAnswers().mapIt(it.id)
            for other in connections:
              if other.key notin idlist:
                continue
              if other.readyState == Open:
                asyncCheck other.send($(%* {"kind": $res.kind, "data": res.data}))
                log fmt"send {other.key}."
          of sdNotAnswerer:
            let idlist = getNotAnswers().mapIt(it.id)
            for other in connections:
              if other.key notin idlist:
                continue
              if other.readyState == Open:
                asyncCheck other.send($(%* {"kind": $res.kind, "data": res.data}))
                log fmt"send {other.key}."
          of sdYou:
            asyncCheck ws.send($(%* {"kind": $res.kind, "data": res.data}))
          else:
            discard
    except WebSocketClosedError:
      log getCurrentExceptionMsg()
      log "Socket closed. "
    except WebSocketProtocolMismatchError:
      log "Socket tried to use an unknown protocol: ", getCurrentExceptionMsg()
    except WebSocketError:
      log "Unexpected socket error: ", getCurrentExceptionMsg()
    except:
      log "Other Error: ", getCurrentExceptionMsg()
  await req.respond(Http200, "Hello World")


when isMainModule:
  connections = newSeq[WebSocket]()
  setLogger()

  var server = newAsyncHttpServer()
  waitFor server.serve(Port(8000), cb)

