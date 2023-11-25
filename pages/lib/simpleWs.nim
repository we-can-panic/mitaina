from dom import Event, EventTarget
import jsffi

type
  StatusCode* = enum
    scNormal = 1000
    scGoingAway = 1001
    scProtocolError = 1002
    scUnsupported = 1003
    scReserved = 1004
    scNoStatus = 1005
    scAbnormal = 1006
    scUnsupportedData = 1007
    scPolicyViolation = 1008
    scTooLarge = 1009
    scMissingExt = 1010
    scInternalError = 1011
    scRestart = 1012
    scTryAgainLater = 1013
    scReserved2 = 1014
    scTLSHandshake = 1015

  MessageEvent* {.importc.} = object of Event
    data*: cstring
    origin*: cstring

var ws {.exportc.}: JsObject

proc newWebSocket*(url: cstring) {.importjs: "ws = new WebSocket(#)".}
proc wsSend*(data: cstring) {.importjs: "ws.send(#)".}
proc wsClose*() {.importjs: "ws.close()".}
proc wsClose*(code: StatusCode | Natural) {.importjs: "ws.close(#)".}
proc wsClose*(code: StatusCode | Natural, reason: cstring) {.importjs: "ws.close(@)".}
proc wsSetOnRecv*(fn: proc(ev: MessageEvent)) {.importjs: "ws.onmessage = (ev)=>{#(ev)}".}

when isMainModule:
  newWebSocket("ws://127.0.0.1:8000/ws")

  proc echoMsg(ev: MessageEvent) {.exportc.} = echo "Received: ", ev.data

  wsSetOnRecv(echoMsg)

  # --

  include karax/prelude

  proc main(): VNode =
    buildHtml tdiv:
      button():
        text "Click Here"
        proc onclick() =
          wsSend("test")

  setRenderer main