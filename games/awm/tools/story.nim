## Prints a hosted replay as a story: each turn's plays, lives and boards.
##
##   story STATUS.json REPLAY_DIR JOB_ID
##   story STATUS.json REPLAY_DIR --losses LABEL [MAX]
##
## The second form lists jobs where LABEL died with four or more alive.

import
  std/[json, os, strformat, strutils],
  zippy, sim, match, replays

proc load(path: string): ReplayData =
  ## Decodes a raw or gzip replay.
  var raw = readFile(path)
  if raw.len > 2 and raw[0] == '\x1f' and raw[1] == '\x8b':
    raw = uncompress(raw, dfGzip)
  decodeReplayFile(ReplayGame, ReplayGameVersion, raw, ReplayData)

proc labelsOf(episode: JsonNode): seq[string] =
  ## Seat labels from a status episode.
  result = newSeq[string](episode["participants"].len)
  for p in episode["participants"]:
    result[p["position"].getInt] = p["label"].getStr.split(':')[0]

proc board(game: GameState, seat: int): string =
  ## Compact minion list: power/toughness per minion.
  for m in game.players[seat].board:
    if m.card.kind == Minion:
      result.add &"{m.card.name[0 .. 2]}{m.power}/{m.currentToughness} "

proc tell(path: string, labels: seq[string]) =
  ## Prints one game turn by turn.
  let data = load(path)
  var game = newGame(data.header.setup.heroClasses, data.header.setup.seed)
  for i, label in labels:
    echo &"seat {i}: {label} {game.players[i].heroClass}"
  echo "first: seat ", game.currentPlayer
  var lastTurn = -1
  for action in data.actions:
    if game.turnNumber != lastTurn:
      lastTurn = game.turnNumber
      let s = game.currentPlayer
      var lives = ""
      for i in 0 ..< game.playerCount:
        lives.add (if game.dead(i): "x " else: $game.players[i].life & " ")
      echo &"-- turn {game.turnNumber} seat {s} {labels[s]} energy " &
        &"{game.players[s].energy} lives [{lives.strip}]"
      for i in 0 ..< game.playerCount:
        if not game.dead(i):
          echo &"     seat {i} board: {game.board(i)}"
    if action.kind == ActionPlayCard:
      let card = game.players[action.playerId].hand[action.handIndex]
      var targets = ""
      for c in action.choices.toChoices:
        case c.kind
        of HeroChoice: targets.add &" hero{c.owner}"
        of CreatureChoice:
          let loc = game.minionLocation(c.creatureId)
          if loc.found:
            let m = game.players[loc.player].board[loc.index]
            targets.add &" s{c.owner}:{m.card.name[0 .. 2]}{m.power}/{m.currentToughness}"
        else: discard
      echo &"   plays {card.name}{targets}"
    if action.kind == ActionAttack:
      let loc = game.minionLocation(action.attacker.int)
      var who = "?"
      if loc.found:
        let m = game.players[loc.player].board[loc.index]
        who = &"{m.card.name[0 .. 2]}{m.power}/{m.currentToughness}"
      var target = ""
      for c in action.choices.toChoices:
        case c.kind
        of HeroChoice: target = &"hero{c.owner}"
        of CreatureChoice:
          let tl = game.minionLocation(c.creatureId)
          if tl.found:
            let tm = game.players[tl.player].board[tl.index]
            target = &"s{c.owner}:{tm.card.name[0 .. 2]}{tm.power}/{tm.currentToughness}"
        else: discard
      echo &"   attacks {who} -> {target}"
    discard game.applyAction(action)
  echo "winner: seat ", game.winner

proc main() =
  ## Dispatches story or loss listing.
  if paramCount() < 3:
    quit("Usage: story STATUS REPLAY_DIR JOB | --losses LABEL [MAX]", 1)
  let
    status = parseJson(readFile(paramStr(1)))
    directory = paramStr(2)
  if paramStr(3) == "--losses":
    let
      label = paramStr(4)
      limit = if paramCount() >= 5: parseInt(paramStr(5)) else: 10
    var shown = 0
    for e in status["episodes"]:
      if shown >= limit:
        break
      let labels = labelsOf(e)
      let ours = labels.find(label)
      if ours < 0:
        continue
      let data = load(directory / e["job_id"].getStr & ".replay")
      var game = newGame(data.header.setup.heroClasses, data.header.setup.seed)
      var aliveAtDeath = 0
      for action in data.actions:
        var alive = 0
        for i in 0 ..< game.playerCount:
          if not game.dead(i): inc alive
        discard game.applyAction(action)
        if game.dead(ours) and aliveAtDeath == 0:
          aliveAtDeath = alive
      let wanted = if paramCount() >= 6: parseInt(paramStr(6)) else: 4
      if (wanted >= 4 and aliveAtDeath >= 4) or
          (wanted < 4 and aliveAtDeath == wanted):
        echo e["job_id"].getStr, " died with ", aliveAtDeath, " alive as ",
          game.players[ours].heroClass
        inc shown
  else:
    for e in status["episodes"]:
      if e["job_id"].getStr == paramStr(3):
        tell(directory / paramStr(3) & ".replay", labelsOf(e))

main()
