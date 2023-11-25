include karax/prelude
import ../domain/models
import lib/simpleWs

var
  players: seq[Player]
  me: int
  board: Board
  state: GameStatus = gsWait

proc makeWait(): VNode =
  buildHtml tdiv:
    tdiv(id="wait-input"):
      input(`type`="text")

    tdiv(id="wait-button"):
      button():
        text "Enter"
        proc onClick() =

proc wsMain(ev: MessageEvent) {.exportc.} =
  case ApiFromServer:
  

proc main(): VNode =
  buildHtml tdiv:
    case state:
    of gsWait:
      makeWait()

    of gsWaitForQ:
      discard
    of gsWriteQ:
      discard
    of gsSortQ:
      discard
    of gsDisplayQ:
      discard
    of gsPoint:
      discard

when isMainModule:

  newWebSocket("ws://127.0.0.1:8000/ws")

  setRenderer main