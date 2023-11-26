import json, sequtils, tables, random
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
    var player = data["player"].to(Player)
    player.id = key
    let idx = players.find(player)
    if idx == -1:
      players.add(player)
    else:
      players[idx].name = player.name
      players[idx].isAnswer = player.isAnswer
      players[idx].ansId = player.ansId
      players[idx].point = player.point
    return @[
      LogicResponce(dst: sdYou, kind: asTellYourId, data: key),
      LogicResponce(dst: sdAll, kind: asPlayerUpdate, data: $(%(players)))
    ]

  of acGameStart:
    # お題回答者決め
    var rnd = initRand()
    let parent_idx = rnd.rand(0..<players.len)
    for i, _ in players:
      players[i].isAnswer = i == parent_idx
    # お題決め
    var themes = parseFile("themas.json").elems.mapIt(it.getStr)
    themes.shuffle
    board.t1.word = themes[0]
    board.t2.word = themes[1]
    return @[
      LogicResponce(dst: sdAll, kind: asPlayerUpdate, data: $(%players)),
      LogicResponce(dst: sdAll, kind: asBoardUpdate, data: $(%board)),
      LogicResponce(dst: sdAll, kind: asStatusUpdate, data: $gsWriteA)
    ]

  of acAddAns:
    let
      player = data["player"].to(Player)
      idx = players.find(player)
      ans = data["ans"].getStr
    current_ans_id.inc
    if idx != -1:
      board.ans[$current_ans_id] = ans
      players[idx].ansId.add($current_ans_id)
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
    board.t1.hidden = false
    return @[LogicResponce(dst: sdAll, kind: asBoardUpdate, data: $(%(board)))]

  of acOpenT2:
    board.t2.hidden = false
    return @[LogicResponce(dst: sdAll, kind: asBoardUpdate, data: $(%(board)))]


proc getAnswers * (): seq[Player] =
  players.filterIt(it.isAnswer)

proc getNotAnswers * (): seq[Player] =
  players.filterIt(not it.isAnswer)