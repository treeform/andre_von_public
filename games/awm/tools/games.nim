## Summarizes hosted AWM games: seats, classes, death order and causes,
## game length, and per-policy card use, from saved XP status files.
##
##   nim r -d:release games/awm/tools/games.nim REPLAY_DIR STATUS.json...
##
## Each status file's episodes are joined to `REPLAY_DIR/<job>.replay`.

import
  std/[algorithm, json, os, strutils, tables],
  zippy,
  sim, match, replays

type
  SeatResult = object
    label: string
    heroClass: HeroClass
    deathTurn: int  ## Turn number when the seat died, 0 when it survived.
    deathOrder: int  ## 1 = first to die, 0 = survived.
    cause: string  ## "life", "deck", or "" when it survived.
    damageTaken: int
    damageFrom: array[7, int]  ## Minion attack damage by attacking seat.
    spellFrom: array[7, int]  ## Card damage by the playing seat.
    cards: CountTable[string]
    won: bool

  GameResult = object
    job: string
    seats: seq[SeatResult]
    turns: int
    ticks: int
    outcome: string
    first: int

proc loadReplay(path: string): ReplayData =
  ## Reads a raw or gzip replay and validates it.
  var bytes = readFile(path)
  if bytes.len > 2 and bytes[0] == '\x1f' and bytes[1] == '\x8b':
    bytes = uncompress(bytes, dfGzip)
  result = decodeReplayFile(ReplayGame, ReplayGameVersion, bytes, ReplayData)
  result.validate()

proc analyze(path: string, labels: seq[string], job: string): GameResult =
  ## Replays one game and records what happened to each seat.
  let data = loadReplay(path)
  var game = newGame(data.header.setup.heroClasses, data.header.setup.seed)
  result.job = job
  result.first = game.currentPlayer
  for i in 0 ..< game.playerCount:
    result.seats.add SeatResult(
      label: labels[i],
      heroClass: game.players[i].heroClass
    )
  var deaths = 0
  for action in data.actions:
    let seat = action.playerId.int
    var lifeBefore: seq[int]
    for p in game.players:
      lifeBefore.add p.life
    if action.kind == ActionPlayCard:
      let card = game.players[seat].hand[action.handIndex.int]
      result.seats[seat].cards.inc(card.name)
    doAssert game.applyAction(action), "Refused hosted replay action"
    discard game.takeVisualEvents()
    for i in 0 ..< game.playerCount:
      let lost = lifeBefore[i] - game.players[i].life
      if lost > 0:
        result.seats[i].damageTaken += lost
        if action.kind == ActionAttack:
          result.seats[i].damageFrom[seat] += lost
        elif action.kind == ActionPlayCard:
          result.seats[i].spellFrom[seat] += lost
    var dying: seq[int]
    for i in 0 ..< game.playerCount:
      if game.players[i].dead and result.seats[i].deathOrder == 0:
        dying.add i
    if dying.len > 0:
      inc deaths
      for i in dying:
        result.seats[i].deathOrder = deaths
        result.seats[i].deathTurn = game.turnNumber
        result.seats[i].cause =
          if game.players[i].drewFromEmpty: "deck" else: "life"
    result.ticks = action.tick.int
  result.turns = game.turnNumber
  if game.gameOver:
    if game.winner >= 0:
      result.outcome = "won"
      result.seats[game.winner].won = true
    else:
      result.outcome = "draw"
  else:
    result.outcome = "timeout"

proc main() =
  ## Loads every completed episode and prints aggregate tables.
  if paramCount() < 2:
    quit("Usage: games REPLAY_DIR STATUS.json...", 1)
  let directory = paramStr(1)
  var games: seq[GameResult]
  for k in 2 .. paramCount():
    let status = parseJson(readFile(paramStr(k)))
    for episode in status["episodes"]:
      if episode["status"].getStr != "completed":
        continue
      let
        job = episode["job_id"].getStr
        path = directory / job & ".replay"
      if not fileExists(path):
        continue
      var labels = newSeq[string](episode["participants"].len)
      for p in episode["participants"]:
        labels[p["position"].getInt] = p["label"].getStr
      games.add analyze(path, labels, job)

  var maxTicks = 0
  for g in games:
    maxTicks = max(maxTicks, g.ticks)
  echo "games ", games.len, " max ticks ", maxTicks
  var
    outcomes: CountTable[string]
    turns: seq[int]
  for g in games:
    outcomes.inc g.outcome
    turns.add g.turns
  turns.sort()
  echo "outcomes ", outcomes
  if turns.len > 0:
    echo "turns min ", turns[0], " median ", turns[turns.len div 2],
      " max ", turns[^1]

  # Per policy: wins, wins by class, death causes, mean death order.
  var
    policies: seq[string]
    wins, played, deckDeaths, lifeDeaths, firstDeaths: CountTable[string]
    classWins, classPlayed: CountTable[string]
    seatWins, seatPlayed: CountTable[string]
    damage: Table[string, int]
    cards: Table[string, CountTable[string]]
  for g in games:
    for i, s in g.seats:
      if s.label notin policies:
        policies.add s.label
      played.inc s.label
      classPlayed.inc s.label & " " & $s.heroClass
      let relative = (i - g.first + g.seats.len) mod g.seats.len
      seatPlayed.inc s.label & " turn" & $relative
      if s.won:
        wins.inc s.label
        classWins.inc s.label & " " & $s.heroClass
        seatWins.inc s.label & " turn" & $relative
      if s.cause == "deck":
        deckDeaths.inc s.label
      if s.cause == "life":
        lifeDeaths.inc s.label
      if s.deathOrder == 1:
        firstDeaths.inc s.label
      damage[s.label] = damage.getOrDefault(s.label) + s.damageTaken
      if s.label notin cards:
        cards[s.label] = initCountTable[string]()
      for name, count in s.cards:
        cards[s.label].inc(name, count)
  policies.sort()
  for p in policies:
    echo ""
    echo p, ": wins ", wins[p], "/", played[p],
      " firstDeaths ", firstDeaths[p],
      " lifeDeaths ", lifeDeaths[p], " deckDeaths ", deckDeaths[p],
      " damageTaken/game ", formatFloat(damage[p] / played[p], ffDecimal, 1)
    for c in HeroClass:
      let key = p & " " & $c
      if classPlayed[key] > 0:
        echo "  ", c, " ", classWins[key], "/", classPlayed[key]
    for t in 0 ..< 7:
      let key = p & " turn" & $t
      if seatPlayed[key] > 0:
        echo "  turn order ", t, ": ", seatWins[key], "/", seatPlayed[key]
    var pairs: seq[(int, string)]
    for name, count in cards[p]:
      pairs.add (count, name)
    pairs.sort(SortOrder.Descending)
    var line = "  cards"
    for (count, name) in pairs:
      line.add " " & name & "=" & $count
    echo line

  # Damage taken by relation: 1 = from the seat before, 2 = two before.
  for p in policies:
    var attacks, spells: array[7, int]
    var n = 0
    for g in games:
      for i, s in g.seats:
        if s.label != p:
          continue
        inc n
        for j in 0 ..< g.seats.len:
          let relation = (i - j + g.seats.len) mod g.seats.len
          attacks[relation] += s.damageFrom[j]
          spells[relation] += s.spellFrom[j]
    var line = p & " damage/game by seats-before: attacks"
    for r in 0 ..< 4:
      line.add " " & $r & "=" & formatFloat(attacks[r] / n, ffDecimal, 1)
    line.add " spells"
    for r in 0 ..< 4:
      line.add " " & $r & "=" & formatFloat(spells[r] / n, ffDecimal, 1)
    echo line

  # Overall class strength.
  var
    cw, cp: CountTable[string]
  for g in games:
    for s in g.seats:
      cp.inc $s.heroClass
      if s.won:
        cw.inc $s.heroClass
  echo ""
  for c in HeroClass:
    echo "class ", c, " ", cw[$c], "/", cp[$c]

main()
