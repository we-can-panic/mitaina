include karax/prelude
import json, dom, strformat, sequtils
import ../domain/models
import lib/simpleWs

const debug = defined(debug) # -d:debug

var
  players: seq[Player] = block:
    when debug: @[Player(name: "なAAAAAAAAAA", id: "1", isAnswer: true),Player(name: "BBBB", id: "bbbb", isAnswer: false, point: 120)]
    else: @[]
  me: string = block:
    # when debug: "bbbb"
    when debug: "1"
    else: ""
  board = block:
    when debug:
      Board(
        t1: Theme(word: "ガソリンスタンド", hidden: true),
        t2: Theme(word: "図書館", hidden: false),
        ans: @[
          Answer(ans: "司書さんの声が大きい", id: "1", hidden: true),
          Answer(ans: "赤の本、黄色の本、緑の本から自分に合うものを選んで借りる", id: "2", hidden: true),
          Answer(ans: "返却のときに、灰皿をきれいにしてくれる", id: "3", hidden: true),
          Answer(ans: "ドライブスルー", id: "4", hidden: false),
        ],
        ansOrder: @["4", "3", "2", "1"]
      )
    else:
      Board()
  # state: GameStatus = gsWait
  state: GameStatus = block:
    when debug: gsWait
    else: gsLogin

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

func isAnswer(players: seq[Player], id: string): bool =
  let idx = players.find(id)
  return players[idx].isAnswer

#--

func makePlayers(ps: seq[Player]): VNode 

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
          text "password"
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
    makePlayers(players)

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
      text fmt"「"
      span(class=fmt"bggray-{board.t1.hidden}"): text ans1
      text "」みたいな「"
      span(class=fmt"bggray-{board.t2.hidden}"): text ans2
      text "」"


proc makeWriteA(): VNode =
  if not players.isAnswer(me):
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
  if players.isAnswer(me):
    buildHtml tdiv:
      tdiv(id="sortA-Answer", class="columns"):
        for i, ansId in board.ansOrder:
          tdiv(class="answer-column"):
            tdiv(class="answer-icon"):
              text $(i+1)
            tdiv(class="answer-text"):
              text board.ans.filterIt(it.id==ansId)[0].ans
            tdiv(class="answer-button"):
              button(onClick = makeOnClickUp(i)):
                text "△"
              button(onClick = makeOnClickDown(i)):
                text "▽"
      tdiv():
        button(class="answer-button"):
          text "OK"
          proc onClick() =
            wsSend($(%* {
              "kind": $acStartQuestion
            }))
  else:
    buildHtml tdiv:
      text "wait for sort"


proc makeDisplayA(): VNode =
  buildHtml tdiv:
    makeThema(players.isAnswer(me)) # answerであれば見せる
    if players.isAnswer(me):
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
        tdiv(class="answer-column"):
          tdiv(class="answer-icon"):
            text $i
          tdiv(class="answer-text"):
            text block:
              if players.isAnswer(me) or not ans.hidden:
                ans.ans
              else:
                ""
          if players.isAnswer(me) and ans.hidden and not enableSatisfied: # hiddenされている最初のansのみ表示
              button(class="answer-button"):
                text "Open"
                proc onClick() =
                  wsSend($(%* {
                    "kind": acOpenAnswer
                  }))
              enableSatisfied = true
      if not players.isAnswer(me) and board.ans.allIt(not it.hidden):
        button(class="answer-button"):
          text "降参"
          proc onClick() =
            wsSend($(%* {
              "kind": acWhiteFlag
            }))



proc makePoint(): VNode =
  buildHtml tdiv:
    makeThema(true)
    tdiv(class="point-answer"):
      if not players.isAnswer(me): 
        tdiv(class="point-answer-label"):
          tdiv(class="point-answer-label-text"):
            text "評価する答え"
      for i, ansId in board.ansOrder:
        let ans = board.ans.filterIt(it.id==ansId)[0]
        tdiv(id=fmt"point-answer-{i}", class="point-answer-column"):
          tdiv(id=fmt"point-answer-{i}-num", class="point-answer-idx"):
            text $i
          tdiv(id=fmt"point-answer-{i}-name", class="point-answer-text"):
            text ans.ans
          if not players.isAnswer(me):
            if i==0:
              input(`type`="radio", id=fmt"point-answer-{i}-radio", name="point-answer-radio", class="point-answer-radio", checked="")
            else:
              input(`type`="radio", id=fmt"point-answer-{i}-radio", name="point-answer-radio", class="point-answer-radio")
      if not players.isAnswer(me):
        button(class="point-dicision-button"):
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


proc makeResult(): VNode =
  buildHtml tdiv:
    makePlayers(players)

    tdiv(class="result-next"):
      button(id="result-next-button"):
        text "Next"
        proc onClick() =
          wsSend($(%* {
            "kind": $acGameNext
          }))


func makePlayers(ps: seq[Player]): VNode =
  buildHtml tdiv(id="players"):
    for i, p in ps:
      tdiv(class="players-column"):
        tdiv(class="players-icon"): text $i
        tdiv(class="players-text"): text p.name
        tdiv(class="players-point"): text $p.point 



proc main(): VNode =
  buildHtml tdiv:
    makeHeader()

    when debug:
      tdiv(class="debug-text"):
        text fmt"""
        state: {state}
        me: {me}
        isAnswer: {players.isAnswer(me)}
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

    of gsResult:
      makeResult()

when isMainModule:

  newWebSocket("ws://127.0.0.1:8000/ws")

  wsSetOnRecv(onRecv)

  setRenderer main