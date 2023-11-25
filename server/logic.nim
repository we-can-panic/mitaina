import json
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
  players: seq[Player]
  board: Board

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
      player = data["user"].to(Player)
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
    discard
  of acChangeAnsOrder:
    discard
  of acOpenT1:
    discard
  of acOpenT2:
    discard




