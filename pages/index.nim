include karax/prelude
import json, dom, strformat
import ../domain/models
import lib/simpleWs

var
  players: seq[Player]
  me: string
  board: Board
  state: GameStatus = gsLogin

proc onRecv(ev: MessageEvent) =
  let data = parseJson($ev.data)
  echo data
  case data["kind"].to(ApiFromServer):
  of asTellYourId:
    me = data["data"].getStr
  of asPlayerUpdate:
    players = data["data"].to(seq[Player])
  of asStatusUpdate:
    state = data["data"].to(GameStatus)
  of asBoardUpdate:
    board = data["data"].to(Board)
  redraw()


func find(players: seq[Player], id: string): int =
  for i, p in players:
    if p.id == id:
      return i
  return -1


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
      button(class="button"):
        text "Enter"
        proc onClick() =
          # make me
          let
            name = $getElementById("login-parameter-name-input").value
            num = $getElementById("login-parameter-pass-input").value

          if name == "" or num == "":
            window.alert("nameかpassを入力してください!")
            return

          # regist
          wsSend($(%* {
            "kind": $acPlayerUpdate,
            "player": Player(name: name)
          }))
          # update param
          state = gsWait

proc makeWait(): VNode =
  buildHtml tdiv:
    tdiv(id="wait-playerinfo", class="columns"):
      for i, p in players:
        tdiv(id=fmt"wait-playerinfo-{i}", class="column"):
          tdiv(id=fmt"wait-playerinfo-{i}-icon", class="column-inner"):
            tdiv(class="player-icon"):
              text $p.name[0]
          tdiv(id=fmt"wait-playerinfo-{i}-name", class="column-inner"):
            text p.name

    tdiv(id="wait-start-button"):
      button():
        text "Start"
        proc onClick() =
          wsSend($(%* {
            "kind": $acGameStart
          }))


proc makeWriteA(): VNode =
  buildHtml tdiv:
    tdiv(id="writeA-answer"):
      input(id="writeA-answer-1", `type`="text")
      input(id="writeA-answer-2", `type`="text")

    tdiv(id="writeA-send"):
      button():
        text "送信"
        proc onClick() =
          let
            ans1 = $getElementById("writeA-answer-1").value
            ans2 = $getElementById("writeA-answer-2").value
          if ans1 == "" or ans2 == "":
            window.alert("お題2つを入力してください!")
            return
          # regist
          let
            idx = players.find(me)
          if idx == -1:
            window.alert("プレイヤーが見つかりませんでした!")
            return
          wsSend($(%* {
            "kind": $acAddAns,
            "player": players[idx],
            "ans": ans1
          }))
          wsSend($(%* {
            "kind": $acAddAns,
            "player": players[idx],
            "ans": ans2
          }))








proc main(): VNode =
  buildHtml tdiv:
    makeHeader()
    text $state
    case state:
    of gsLogin:
      makeLogin()

    of gsWait:
      makeWait()

    of gsWriteA:
      makeWriteA()

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