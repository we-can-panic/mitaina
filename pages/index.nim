include karax/prelude
import json, dom, strformat
import ../domain/models
import lib/simpleWs

var
  players: seq[Player]
  me: string
  board: Board
  state: GameStatus = gsWait

proc onRecv(ev: MessageEvent) =
  let data = parseJson($ev.data)
  case data["kind"].to(ApiFromServer):
  of asTellYourId:
    me = data["data"].getStr
  of asPlayerUpdate:
    players = data["data"].to(seq[Player])
  of asStatusUpdate:
    state = data["data"].to(GameStatus)
  of asBoardUpdate:
    board = data["data"].to(Board)

#--

proc makeHeader(): VNode =
  buildHtml tdiv:
    h1:
      text "MITAINA"

proc makeLogin(): VNode =
  buildHtml tdiv:
    tdiv(id="login-parameter"):
      tdiv(id="login-parameter-name"):
        label:
          text "name"
        input(id="login-parameter-name-input", `type`="text")
      tdiv(id="login-parameter-pass"):
        label:
          text "passcode"
        input(id="login-parameter-pass-input", `type`="number")
    tdiv(id="login-button"):
      button():
        text "Enter"
        proc onClick() =
          # make me
          let
            name = $getElementById("login-parameter-name-input").value
            num = $getElementById("login-parameter-pass-input").value

          if name == "" or num == "":
            window.alert("nameかpassを入力してください!")

          # regist
          wsSend($(%* {
            "kind": $acPlayerUpdate,
            "data": $(%Player(name: name))
          }))
          # update param
          state = gsWait

proc makeWait(): VNode =
  buildHtml tdiv:
    for i, p in players:
      tdiv(id=fmt"wait-playerinfo-{i}"):
        tdiv(id="wait-playerinfo-{i}-icon"):
          tdiv(class="player-icon"):
            text $p.name[0]
        tdiv(id="wait-playerinfo-{i}-name"):
          text p.name
    
    tdiv(id="wait-start-button"):
      button():
        text "Start"
        proc onClick() =
          wsSend($(%* {
            "kind": $acGameStart
          }))


proc main(): VNode =
  buildHtml tdiv:
    makeHeader()
    case state:
    of gsLogin:
      makeLogin()

    of gsWait:
      makeWait()

    of gsWriteA:
      discard
    of gsSortA:
      discard
    of gsDisplayA:
      discard
    of gsPoint:
      discard

when isMainModule:

  newWebSocket("ws://127.0.0.1:8000/ws")

  wsSetOnRecv(onRecv)

  setRenderer main