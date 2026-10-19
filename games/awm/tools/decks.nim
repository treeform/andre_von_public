## Prints each seat's final life, deck, hand and draw-card plays for one
## hosted replay, to study deck-out races.
##
##   decks STATUS.json REPLAY_DIR JOB_ID

import
  std/[json, os, strutils],
  zippy, sim, match, replays

proc main() =
  ## Replays one game and reports per-seat deck statistics.
  let
    status = parseJson(readFile(paramStr(1)))
    path = paramStr(2) / paramStr(3) & ".replay"
  var labels: seq[string]
  for e in status["episodes"]:
    if e["job_id"].getStr == paramStr(3):
      labels = newSeq[string](e["participants"].len)
      for p in e["participants"]:
        labels[p["position"].getInt] = p["label"].getStr
  var raw = readFile(path)
  if raw.len > 2 and raw[0] == '\x1f' and raw[1] == '\x8b':
    raw = uncompress(raw, dfGzip)
  let data = decodeReplayFile(ReplayGame, ReplayGameVersion, raw, ReplayData)
  var game = newGame(data.header.setup.heroClasses, data.header.setup.seed)
  var plans, studies, turns: seq[int]
  for i in 0 ..< game.playerCount:
    plans.add 0
    studies.add 0
    turns.add 0
  var lastTurn = -1
  for action in data.actions:
    if game.turnNumber != lastTurn:
      lastTurn = game.turnNumber
      inc turns[game.currentPlayer]
    if action.kind == ActionPlayCard:
      let card = game.players[action.playerId].hand[action.handIndex]
      if card.name == "Plan": inc plans[action.playerId]
      if card.name == "Study": inc studies[action.playerId]
    discard game.applyAction(action)
  echo "turn ", game.turnNumber, " winner ", game.winner
  for i in 0 ..< game.playerCount:
    let p = game.players[i]
    echo i, " ", labels[i], ": life ", p.life, " dead ", p.dead,
      " deckOut ", p.drewFromEmpty, " deck ", p.deck.len, " hand ",
      p.hand.len, " ownTurns ", turns[i], " plans ", plans[i],
      " studies ", studies[i]

main()
