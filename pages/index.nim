include karax/prelude
import json, dom, strformat, sequtils
import ../domain/models
import lib/simpleWs

const debug = true

var
  players: seq[Player] = @[Player(name: "AAAAAAAAAA"),Player(name: "BBBB", id: "bbbb", isAnswer: true)]
  me: string = "bbbb"
  board = Board(
    t1: Theme(word: "ガソリンスタンド", hidden: true),
    t2: Theme(word: "図書館", hidden: false)
  )
  state: GameStatus = gsDisplayA

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


func find(answers: seq[Answer], id: string): int =
  for i, a in answers:
    if a.id == id:
      return i
  return -1


#--

proc makeHeader(): VNode =
  buildHtml tdiv:
    h1:
      text "MITAINA"

proc makeLogin(): VNode =
  buildHtml tdiv(class="login"):
    tdiv(id="login-parameter"):
      tdiv(id="login-parameter-name"):
        label:
          text "name"
        input(id="login-parameter-name-input", `type`="text")
      tdiv(id="login-parameter-pass"):
        label:
          text "passwprd"
        input(id="login-parameter-pass-input", `type`="password")
    tdiv():
      button(id="login-button"):
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
    tdiv(id="wait-playerinfo", class="player-columns"):
      for i, p in players:
        tdiv(id=fmt"wait-playerinfo-{i}", class=block:
          if me == p.id: "player-column is-me"
          else: "player-column"
          ):
          tdiv(id=fmt"wait-playerinfo-{i}-icon", class="player-icon"):
            text $p.name[0]
          tdiv(id=fmt"wait-playerinfo-{i}-name", class="player-text"):
            text p.name

    tdiv(id="wait-start"):
      button(id="wait-start-button"):
        text "Start"
        proc onClick() =
          wsSend($(%* {
            "kind": $acGameStart
          }))


proc makeThema(displayHidden=false): VNode =
  let
    ans1 = block:
      if not board.t1.hidden or displayHidden:
        board.t1.word
      else:
        ""
    ans2 = block:
      if not board.t2.hidden or displayHidden:
        board.t2.word
      else:
        ""
  buildHtml tdiv(class="thema"):
    tdiv(class="thema-title"):
      text "お題"
    tdiv(class="thema-text"):
      text fmt"「{ans1}」みたいな「{ans2}」"


proc makeWriteA(): VNode =
  let myplayer = block:
    let idx = players.find(me)
    players[idx]

  if not myplayer.isAnswer:
    return buildHtml tdiv(class="waiting"):
      text "waiting for answer..."

  buildHtml tdiv:
    makeThema(true)

    tdiv(id="writeA-answer"):
      tdiv(class="writeA-answer-column"):
        label: text "回答1:"
        textarea(id="writeA-answer-1", `type`="text", class="writeA-answer-text")
      tdiv(class="writeA-answer-column"):
        label: text "回答2:"
        textarea(id="writeA-answer-2", `type`="text", class="writeA-answer-text")

    tdiv(id="writeA-send"):
      button(class="writeA-send-button"):
        text "送信"
        proc onClick() =
          let
            ans1 = $getElementById("writeA-answer-1").value
            ans2 = $getElementById("writeA-answer-2").value
          if ans1 == "" or ans2 == "":
            window.alert("回答2つを入力してください!")
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


func makeOnClickUp(i: int): proc () =
  proc onClick() = # i-1とiの値を入れ替え
    if i == 0: return
    let k = board.ansOrder[i-1]
    board.ansOrder[i-1] = board.ansOrder[i]
    board.ansOrder[i] = k
    wsSend($(%* {
      "kind": $acChangeAnsOrder,
      "ansOrder": board.ansOrder
    }))
  return onClick

func makeOnClickDown(i: int): proc () =
  proc onClick() = # i+1とiの値を入れ替え
    if i == board.ansOrder.len-1: return
    let k = board.ansOrder[i+1]
    board.ansOrder[i+1] = board.ansOrder[i]
    board.ansOrder[i] = k
    wsSend($(%* {
      "kind": $acChangeAnsOrder,
      "ansOrder": board.ansOrder
    }))
  return onClick

proc makeSortA(): VNode =
  let myplayer = block:
    let idx = players.find(me)
    players[idx]
  if myplayer.isAnswer:
    buildHtml tdiv:
      tdiv(id="sortA-Answer", class="columns"):
        for i, ansId in board.ansOrder:
          tdiv(id=fmt"sortA-Answer-{i}", class="column"):
            tdiv(id=fmt"sortA-Answer-{i}-num", class="column-inner"):
              text $i
            tdiv(id=fmt"sortA-Answer-{i}-name", class="column-inner"):
              text board.ans.filterIt(it.id==ansId)[0].ans
            tdiv(id=fmt"sortA-Answer-{i}-buttons", class="column-inner"):
              button(onClick = makeOnClickUp(i)):
                text "△"
              button(onClick = makeOnClickDown(i)):
                text "▽"
      tdiv(id="sortA-decision"):
        button(id="sortA-decision-button"):
          text "OK"
          proc onClick() =
            wsSend($(%* {
              "kind": $acStartQuestion
            }))
  else:
    buildHtml tdiv:
      text "wait for sort"


proc makeDisplayA(): VNode =
  let myplayer = block:
    let idx = players.find(me)
    players[idx]
  buildHtml tdiv:
    makeThema(myplayer.isAnswer) # answerであれば見せる
    if myplayer.isAnswer:
      tdiv(class="displayA-open"):
        button(class=fmt"displayA-open-button button-{board.t1.hidden}"):
          text "1つめの単語を公開"
          proc onClick() =
            wsSend($(%* {
              "kind": %acOpenT1
            }))

        button(class=fmt"displayA-open-button button-{board.t2.hidden}"):
          text "2つめの単語を公開"
          proc onClick() =
            wsSend($(%* {
              "kind": %acOpenT2
            }))

    tdiv(id="displayA-Answer", class="columns"):
      var enableSatisfied = false
      for i, ansId in board.ansOrder:
        let ans = board.ans.filterIt(it.id==ansId)[0]
        tdiv(id=fmt"displayA-Answer-{i}", class="column"):
          tdiv(id=fmt"displayA-Answer-{i}-num", class="column-inner"):
            text $i
          tdiv(id=fmt"displayA-Answer-{i}-name", class="column-inner"):
            text block:
              if myplayer.isAnswer or not ans.hidden:
                ans.ans
              else:
                ""
          if myplayer.isAnswer:
            tdiv(id=fmt"displayA-Answer-{i}-button", class="column-inner"):
              let apear = block:
                if not enableSatisfied and ans.hidden: # hiddenされている最初のcolのみ表示
                  enableSatisfied = true
                  true
                else:
                  false
              if apear:
                button():
                  text "Open"
                  proc onClick() =
                    wsSend($(%* {
                      "kind": acOpenAnswer
                    }))


proc makePoint(): VNode =
  let myplayer = block:
    let idx = players.find(me)
    players[idx]
  buildHtml tdiv:
    makeThema(true)
    tdiv(id="point-answer", class="columns"):
      for i, ansId in board.ansOrder:
        let ans = board.ans.filterIt(it.id==ansId)[0]
        tdiv(id=fmt"point-answer-{i}", class="column"):
          tdiv(id=fmt"point-answer-{i}-num", class="column-inner"):
            text $i
          tdiv(id=fmt"point-answer-{i}-name", class="column-inner"):
            text ans.ans
          if not myplayer.isAnswer:
            input(`type`="radio", id=fmt"point-answer-{i}-radio", name="point-answer-radio")
      if not myplayer.isAnswer:
        button():
          text "決定"
          proc onClick() =
            let values = document.getElementsByName("point-answer-radio")
            var idx = -1
            for i, v in values:
              if v.checked:
                idx = i

            wsSend($(%* {
              "kind": acBestAnswer,
              "idx": idx
            }))





proc main(): VNode =
  buildHtml tdiv:
    makeHeader()

    when debug:
      tdiv(class="debug-text"):
        text fmt"""
        state: {state}
        """

    case state:
    of gsLogin:
      makeLogin()

    of gsWait:
      makeWait()

    of gsWriteA:
      makeWriteA()

    of gsSortA:
      makeSortA()

    of gsDisplayA:
      makeDisplayA()

    of gsPoint:
      makePoint()

when isMainModule:

  newWebSocket("ws://127.0.0.1:8000/ws")

  wsSetOnRecv(onRecv)

  setRenderer main