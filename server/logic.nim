import json, sequtils
import ../domain/models
import logutils

type
  SendDistination* = enum # ApiFromServerの送り先
    sdAll             # 全員
    sdAnswerer        # お題回答者
    sdNotAnswerer     # ボケの出題者
    sdYou             # APIを投げてきた人
    sdNone            # 返さない

  LogicResponce* = object
    dst*: SendDistination
    kind*: ApiFromServer
    data*: string         # stringifyされたJSON（=何でも送信可能

var
  players {.threadvar.}: seq[Player]
  board: Board
  current_ans_id = 0

proc find(players: seq[Player], player: Player): int =
  for i, p in players:
    if p.id == player.id:
      return i
  return -1

proc calc * (key: string, dataStr: string): seq[LogicResponce] =
  let data = parseJson(dataStr)

  case data["kind"].to(ApiFromClient):
  of acPlayerUpdate:
    let
      player = data["player"].to(Player)
      idx = players.find(player)
    if idx == -1:
      players.add(player)
    else:
      players[idx].name = player.name
      players[idx].isAnswer = player.isAnswer
      players[idx].ansId = player.ansId
      players[idx].point = player.point
    return @[LogicResponce(dst: sdAll, kind: asPlayerUpdate, data: $(%(players)))]

  of acAddAns:
    let
      player = data["player"].to(Player)
      idx = players.find(player)
      ans = data["ans"].getStr
    current_ans_id.inc
    if idx != -1:
      board.ans[current_ans_id] = ans
      players[idx].ansId.add(current_ans_id)
    else:
      raise newException(ValueError, "acAddAns: player data is not valid")
    return @[
      LogicResponce(dst: sdAll, kind: asBoardUpdate, data: $(%(board))),
      LogicResponce(dst: sdAll, kind: asPlayerUpdate, data: $(%(players)))
    ]

  of acChangeAnsOrder:
    board.ansOrder = data["ansOrder"].elems.mapIt(it.getStr)
    return @[LogicResponce(dst: sdAll, kind: asBoardUpdate, data: $(%(board)))]

  of acOpenT1:
    discard
  of acOpenT2:
    discard


proc getAnswers * (): seq[Player] =
  players.filterIt(it.isAnswer)

proc getNotAnswers * (): seq[Player] =
  players.filterIt(not it.isAnswer)