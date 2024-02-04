import tables, json

#[
  ## 共通ワード
  - thema: お題
  - Answer: お題回答者（誰かひとり）
  - ans: 答え（ボケ）

  ## ゲームの流れ
  - ユーザが集合
  - ゲームスタート
  - お題提示（Answer以外）
  - 答えの募集（Answer以外）
  - 答えの並び替え（Answer以外）
  - 答えの提示（Answer以外）
  - お題の回答（Answer; 口頭でおこなう）
  - 合っていると感じたらお題オープン（Answer以外）
  - ポイント計算
    - 一番良い答えを決定（Answer）
    - ポイント割り振り
  - ゲームスタートへ
]#

type
  Player* = object # プレイヤーオブジェクト
    id* : string        # id (= ws.key)
    name*: string       # 任意の文字列
    isAnswer*: bool     # お題回答者か否か
    ansId*: seq[string] # 出した回答のID
    point*: int         # ポイント

  Theme* = object
    word*: string
    hidden*: bool = true

  Answer* = object
    ans*: string
    id*: string
    hidden*: bool = true

  Board* = object # 盤面オブジェクト
    t1*, t2*: Theme        # お題のワード
    ans*: seq[Answer]      # 回答IDと回答
    ansOrder*: seq[string] # 回答者に見せる順番

  GameStatus* = enum # Front用のステップ
    gsLogin    # 最初のログイン画面
    gsWait     # ユーザが集まるまで待機
    gsWriteA   # 答えを記入
    gsSortA    # 答えの順番を並び替え
    gsDisplayA # 答えを提示
    gsPoint    # ポイント計算
    gsResult   # 得点表示

  ApiFromServer* = enum # サーバからのAPI
    asTellYourId
    asStatusUpdate # statusのupdate
    asPlayerUpdate
    asBoardUpdate

  ApiFromClient* = enum # クライアントからのAPI
    acPlayerUpdate   # playerのUpdate（自分一人しかいじらない
    acGameStart      # ゲーム開始
    acAddAns         # 回答の登録
    acChangeAnsOrder # ansorderの変更
    acStartQuestion  # 回答開始
    acOpenAnswer     # 回答の開示
    acWhiteFlag      # 降参
    acOpenT1         # お題の回答
    acOpenT2
    acBestAnswer     # 一番良い答えを決定
    acGameNext

