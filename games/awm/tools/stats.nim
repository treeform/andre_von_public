## Batch replay stats for AWM: one row per stat, one column per policy.
## The first label is our policy, the rest are the top opponents.
##
##   nim c -d:release games/awm/tools/stats.nim
##   stats REPLAY_DIR OUT.md "ours:vN,top1:vN,top2:vN,top3:vN" STATUS.json...
##
## Stats are grouped by how directly a policy controls them: its own card
## and target choices, what it gets to play given its draws, and outcomes.

import
  std/[json, os, strformat, strutils, tables],
  zippy,
  sim, match, replays

type
  Sums = Table[string, float]
  Row = object
    group: int  ## 1 direct, 2 indirect, 3 outcome.
    title: string
    num, den: string  ## Sum keys; an empty den means a plain sum per game.
    scale: float
    digits: int

var stats: Table[string, Sums]

proc add(label, key: string, value = 1.0) =
  ## Adds to one policy's named sum.
  if label notin stats:
    stats[label] = initTable[string, float]()
  stats[label][key] = stats[label].getOrDefault(key) + value

proc get(label, key: string): float =
  ## Reads one policy's named sum, zero when never recorded.
  if label notin stats:
    return 0
  stats[label].getOrDefault(key)

proc loadReplay(path: string): ReplayData =
  ## Reads a raw or gzip replay and validates it.
  var bytes = readFile(path)
  if bytes.len > 2 and bytes[0] == '\x1f' and bytes[1] == '\x8b':
    bytes = uncompress(bytes, dfGzip)
  result = decodeReplayFile(ReplayGame, ReplayGameVersion, bytes, ReplayData)
  result.validate()

proc prevLiving(game: GameState, player: int): int =
  ## The living player whose minions attack `player`.
  let n = game.playerCount
  for step in 1 ..< n:
    let candidate = (player - step + n) mod n
    if not game.dead(candidate):
      return candidate
  player

proc relation(game: GameState, actor, owner: int): string =
  ## Names a seat relative to the actor in the current living ring.
  if owner == actor:
    return "self"
  if game.dead(owner):
    return "dead"
  let
    next = game.nextPlayer(actor)
    prev = game.prevLiving(actor)
  if owner == next:
    return "next"
  if owner == prev:
    return "prev"
  if owner == game.prevLiving(prev):
    return "prev2"
  "other"

proc minionCount(game: GameState, player: int): int =
  ## Minions (not trinkets) on a player's board.
  for minion in game.players[player].board:
    if minion.card.kind == Minion:
      inc result

proc boardPower(game: GameState, player: int): int =
  ## Total live power of a player's minions.
  for minion in game.players[player].board:
    if minion.card.kind == Minion:
      result += minion.power

proc minionIds(game: GameState, player: int): Table[int, int] =
  ## Minion id to power for one board.
  for minion in game.players[player].board:
    if minion.card.kind == Minion:
      result[minion.id] = minion.power

proc affordable(game: GameState, player: int): bool =
  ## True when the hand holds a card the player could still play.
  for i, card in game.players[player].hand:
    if card.energyCost > game.players[player].energy:
      continue
    if not card.needsChoice():
      return true
    for choice in game.availableChoices(i):
      if choice.kind in {HeroChoice, CreatureChoice}:
        return true
  false

proc analyze(path: string, labels: seq[string]) =
  ## Replays one game and adds every seat's stats to its policy.
  let data = loadReplay(path)
  var game = newGame(data.header.setup.heroClasses, data.header.setup.seed)
  let n = game.playerCount
  var
    turnOpen = newSeq[bool](n)  ## The seat is still choosing cards.
    turnPlays = newSeq[int](n)
    ownTurns = newSeq[int](n)
    deathTurn = newSeq[int](n)
    firstDeath = -1
    deaths = 0
    lastSeat = -1
    reachedFinal = n == 2
  let first = game.currentPlayer
  for seat in 0 ..< n:
    let label = labels[seat]
    add(label, "games")
    add(label, "games " & $game.players[seat].heroClass)
    if seat == first:
      add(label, "first games")

  proc openTurn(game: GameState, seat: int) =
    ## Records the start of a seat's turn.
    let label = labels[seat]
    turnOpen[seat] = true
    turnPlays[seat] = 0
    inc ownTurns[seat]
    add(label, "turns")
    add(label, "energy available", game.players[seat].energy.float)
    add(label, "hand at start", game.players[seat].hand.len.float)

  proc closeTurn(game: GameState, seat: int) =
    ## Records how a seat ended its card plays.
    let label = labels[seat]
    turnOpen[seat] = false
    add(label, "energy left", game.players[seat].energy.float)
    if game.affordable(seat):
      add(label, "ended with playable card")
      add(label, "energy left when playable", game.players[seat].energy.float)
    if turnPlays[seat] == 0:
      add(label, "empty turns")
    add(label, "board minions at end", game.minionCount(seat).float)
    add(label, "board power at end", game.boardPower(seat).float)
    add(label, "hand at end", game.players[seat].hand.len.float)

  game.openTurn(game.currentPlayer)
  lastSeat = game.currentPlayer
  for action in data.actions:
    let
      seat = action.playerId.int
      label = labels[seat]
    var
      lives: seq[int]
      boards: seq[Table[int, int]]
      hands: seq[int]
    for p in 0 ..< n:
      lives.add game.players[p].life
      boards.add game.minionIds(p)
      hands.add game.players[p].hand.len
    let wasDead = block:
      var d: seq[bool]
      for p in 0 ..< n:
        d.add game.dead(p)
      d
    var
      cardName = ""
      choices: seq[Choice]
      relations: seq[string]
    case action.kind
    of ActionPlayCard:
      let card = game.players[seat].hand[action.handIndex.int]
      cardName = card.name
      choices = action.choices.toChoices
      for choice in choices:
        case choice.kind
        of HeroChoice:
          relations.add "hero " & game.relation(seat, choice.owner)
        of CreatureChoice:
          relations.add "minion " & game.relation(seat, choice.owner)
        else:
          relations.add "none"
      inc turnPlays[seat]
      add(label, "plays")
      add(label, "energy spent", card.energyCost.float)
      add(label, "card " & cardName)
      add(label, "card " & $game.players[seat].heroClass & " " & cardName)
      if turnPlays[seat] == 1:
        add(label, "first card " & cardName)
    of ActionAttack, ActionEndTurn:
      if seat == game.currentPlayer and turnOpen[seat]:
        game.closeTurn(seat)
    else:
      discard
    let mover = game.currentPlayer
    doAssert game.applyAction(action), "Refused hosted replay action"
    discard game.takeVisualEvents()

    # Hero damage, by the acting seat and its relation to each victim.
    for p in 0 ..< n:
      let lost = lives[p] - game.players[p].life
      if lost <= 0:
        continue
      let victim = labels[p]
      var rel = "other"
      if p == seat:
        rel = "self"
      else:
        # Relation of the actor to the victim before this action.
        var before = game
        for q in 0 ..< n:
          before.players[q].dead = wasDead[q]
        let r = before.relation(p, seat)
        rel = r
      if action.kind == ActionAttack:
        add(victim, "taken attack " & rel, lost.float)
        add(label, "dealt attack", lost.float)
      else:
        add(victim, "taken spell " & rel, lost.float)
        add(label, "dealt spell", lost.float)
        if cardName.len > 0:
          add(label, "hero damage " & cardName, lost.float)
      add(victim, "taken", lost.float)

    if action.kind == ActionPlayCard:
      # Minions removed by this card, by owner relation, and own losses.
      var
        removed = 0
        removedPower = 0
        ownLost = 0
      for p in 0 ..< n:
        let after = game.minionIds(p)
        for id, power in boards[p]:
          if id in after:
            continue
          if p == seat:
            inc ownLost
          else:
            inc removed
            removedPower += power
            var before = game
            for q in 0 ..< n:
              before.players[q].dead = wasDead[q]
            let rel = before.relation(seat, p)
            add(label, "removed " & rel)
            add(label, "removed power " & rel, power.float)
            add(label, "removed by " & cardName)
      if ownLost > 0:
        add(label, "own lost to own " & cardName, ownLost.float)
      add(label, "cast " & cardName)
      if removed > 0:
        add(label, "cast " & cardName & " removing")
      for rel in relations:
        add(label, cardName & " target " & rel)
      # Wasted casts: effects with no possible gain.
      case cardName
      of "Hail of Arrows":
        var hit = 0
        for p in 0 ..< n:
          if p == seat:
            continue
          for minion in boards[p].keys:
            hit += 1
        if hit == 0:
          add(label, "wasted Hail of Arrows")
      of "Swords", "Shields":
        if boards[seat].len == 0:
          add(label, "wasted " & cardName)
      else:
        discard

    # Deaths and kill credit.
    for p in 0 ..< n:
      if game.dead(p) and not wasDead[p]:
        inc deaths
        deathTurn[p] = ownTurns[p]
        let victim = labels[p]
        add(victim, "died")
        add(victim, "survived own turns", ownTurns[p].float)
        if game.players[p].drewFromEmpty:
          add(victim, "deck deaths")
        if deaths == 1 or firstDeath == -1:
          firstDeath = p
          add(victim, "first deaths")
        add(victim, "death stage " & $(n - deaths + 1))
        if seat != p:
          add(label, "kills")
          var before = game
          for q in 0 ..< n:
            before.players[q].dead = wasDead[q]
          add(victim, "killed by " & before.relation(p, seat))

    # Both survivors reach the final duel once two players remain.
    var living = 0
    for q in 0 ..< n:
      if not game.dead(q):
        inc living
    if living == 2 and not reachedFinal:
      reachedFinal = true
      for q in 0 ..< n:
        if not game.dead(q):
          add(labels[q], "reached final")

    # A new turn begins after an end-turn action.
    if action.kind == ActionEndTurn and not game.gameOver:
      game.openTurn(game.currentPlayer)
    discard mover
    discard hands

  for seat in 0 ..< n:
    let label = labels[seat]
    if game.gameOver and game.winner == seat:
      add(label, "wins")
      add(label, "wins " & $game.players[seat].heroClass)
      if seat == first:
        add(label, "first wins")
      add(label, "survived own turns", ownTurns[seat].float)
      add(label, "winner own turns", ownTurns[seat].float)
    elif not game.dead(seat):
      add(label, "survived own turns", ownTurns[seat].float)
  add(labels[0], "game turns total", game.turnNumber.float)

proc cell(label: string, row: Row): string =
  ## Formats one policy's value for a row.
  let games = get(label, "games")
  if games == 0:
    return "-"
  let num = get(label, row.num)
  var value: float
  if row.den.len == 0:
    value = num / games
  else:
    let den = get(label, row.den)
    if den == 0:
      return "-"
    value = num / den
  formatFloat(value * row.scale, ffDecimal, row.digits)

proc value(label: string, row: Row): float =
  ## The numeric value behind a cell, or NaN.
  let games = get(label, "games")
  if games == 0:
    return NaN
  let num = get(label, row.num)
  if row.den.len == 0:
    return num / games
  let den = get(label, row.den)
  if den == 0:
    return NaN
  num / den * row.scale

proc rows(): seq[Row] =
  ## The stat table definition.
  proc r(group: int, title, num, den: string, scale = 1.0,
      digits = 2): Row =
    Row(group: group, title: title, num: num, den: den, scale: scale,
      digits: digits)
  # Direct: choices the policy makes with what it holds.
  result.add r(1, "cards played per turn", "plays", "turns")
  result.add r(1, "energy used %", "energy spent", "energy available",
    100, 1)
  result.add r(1, "turns ended holding a playable card %",
    "ended with playable card", "turns", 100, 1)
  result.add r(1, "energy left when a card was playable",
    "energy left when playable", "ended with playable card")
  result.add r(1, "empty turns %", "empty turns", "turns", 100, 1)
  for card in ["Bolt", "Sharpshooter", "Bouncer", "Oozification",
      "Tactician", "Duel"]:
    for rel in ["hero next", "hero prev", "hero prev2", "hero other",
        "minion prev", "minion prev2", "minion next", "minion other",
        "minion self", "minion dead", "none"]:
      if card == "Bolt" and not rel.startsWith("hero"):
        continue
      if card in ["Bouncer", "Oozification", "Tactician", "Duel"] and
          rel.startsWith("hero"):
        continue
      result.add r(1, card & " target " & rel & " %",
        card & " target " & rel, "cast " & card, 100, 1)
  result.add r(1, "wasted Hail of Arrows (no enemy minions) %",
    "wasted Hail of Arrows", "cast Hail of Arrows", 100, 1)
  result.add r(1, "wasted Swords (no own minions) %", "wasted Swords",
    "cast Swords", 100, 1)
  result.add r(1, "wasted Shields (no own minions) %", "wasted Shields",
    "cast Shields", 100, 1)
  for card in ["Hail of Arrows", "Sharpshooter", "Duel", "Oozification",
      "Bouncer", "Tactician", "Primordial"]:
    result.add r(1, card & " casts that removed a minion %",
      "cast " & card & " removing", "cast " & card, 100, 1)
  result.add r(1, "own minions lost to own Duel per Duel",
    "own lost to own Duel", "cast Duel")
  for card in ["Primordial", "Plan", "Study", "Bubble Shield", "Bolt",
      "Hail of Arrows", "Swords", "Shields", "Rally", "Commander"]:
    result.add r(1, "first card of turn is " & card & " %",
      "first card " & card, "turns", 100, 1)
  # Indirect: what the hand and energy allowed.
  for heroClass in HeroClass:
    let names =
      case heroClass
      of Archer: @["Bolt", "Sniper", "Sharpshooter", "Hail of Arrows"]
      of Warrior: @["Bear", "Footsoldier", "Tactician", "Commander",
        "Swords", "Shields", "Duel", "Rally"]
      of Mage: @["Bouncer", "Study", "Bubble Shield", "Plan",
        "Oozification", "Primordial", "Bubble", "Ooze"]
    for name in names:
      result.add r(2, $heroClass & " " & name & " per game",
        "card " & $heroClass & " " & name, "games " & $heroClass)
  result.add r(2, "energy available per turn", "energy available", "turns")
  result.add r(2, "hand size at turn start", "hand at start", "turns")
  result.add r(2, "hand size at turn end", "hand at end", "turns")
  result.add r(2, "own minions on board at turn end",
    "board minions at end", "turns")
  result.add r(2, "own board power at turn end", "board power at end",
    "turns")
  result.add r(2, "minion attack damage dealt per game", "dealt attack", "")
  result.add r(2, "card damage dealt per game", "dealt spell", "")
  for rel in ["prev", "prev2", "next", "other", "dead"]:
    result.add r(2, "enemy minions removed per game: " & rel,
      "removed " & rel, "")
    result.add r(2, "enemy power removed per game: " & rel,
      "removed power " & rel, "")
  # Outcomes.
  result.add r(3, "win %", "wins", "games", 100, 1)
  for heroClass in HeroClass:
    result.add r(3, "win % as " & $heroClass, "wins " & $heroClass,
      "games " & $heroClass, 100, 1)
  result.add r(3, "win % when moving first", "first wins", "first games",
    100, 1)
  result.add r(3, "first to die %", "first deaths", "games", 100, 1)
  for stage in [5, 4, 3]:
    result.add r(3, "died with " & $stage & " alive %",
      "death stage " & $stage, "games", 100, 1)
  result.add r(3, "reached final duel %", "reached final", "games", 100, 1)
  result.add r(3, "won final duel %", "wins", "reached final", 100, 1)
  result.add r(3, "own turns survived", "survived own turns", "games")
  result.add r(3, "kills per game", "kills", "")
  result.add r(3, "damage taken per game", "taken", "")
  for rel in ["prev", "prev2", "next", "other"]:
    result.add r(3, "attack damage taken from " & rel,
      "taken attack " & rel, "")
    result.add r(3, "card damage taken from " & rel,
      "taken spell " & rel, "")
  result.add r(3, "deck-out deaths per game", "deck deaths", "")
  for rel in ["prev", "prev2", "next", "other"]:
    result.add r(3, "killed by " & rel & " %", "killed by " & rel, "died",
      100, 1)

proc main() =
  ## Loads every completed episode and writes the stat table.
  if paramCount() < 4:
    quit("Usage: stats REPLAY_DIR OUT.md LABELS STATUS.json...", 1)
  let
    directory = paramStr(1)
    output = paramStr(2)
    columns = paramStr(3).split(',')
  var games = 0
  for k in 4 .. paramCount():
    let status = parseJson(readFile(paramStr(k)))
    for episode in status["episodes"]:
      if episode["status"].getStr != "completed":
        continue
      let path = directory / episode["job_id"].getStr & ".replay"
      if not fileExists(path):
        continue
      var labels = newSeq[string](episode["participants"].len)
      for p in episode["participants"]:
        labels[p["position"].getInt] = p["label"].getStr
      analyze(path, labels)
      inc games
  # The opponent with the best win rate is the reference for gaps, and
  # red rows compare us with every opponent that wins more often than us.
  proc rate(label: string): float =
    get(label, "wins") / max(1.0, get(label, "games"))
  var best = columns[1]
  for label in columns[1 .. ^1]:
    if rate(label) > rate(best):
      best = label
  var reference: seq[string]
  for label in columns[1 .. ^1]:
    if rate(label) > rate(columns[0]):
      reference.add label
  if reference.len == 0:
    reference = columns[1 .. ^1]
  let referenceText = reference.join(", ")
  var
    text = &"# AWM policy stats\n\n{games} replays. Gap = ours minus " &
      &"{best} (best opponent win rate). `!` marks rows where we fall " &
      &"outside the range of the stronger opponents ({referenceText}).\n"
    html = "<!doctype html>\n<html><head><meta charset=\"utf-8\">\n" &
      "<title>AWM policy stats</title>\n<style>\n" &
      ":root { --fg: #1d1d1f; --bg: #ffffff; --line: #e3e3e6; " &
      "--head: #f4f4f6; --bad: #fbe7e7; --badfg: #8c1d1d; }\n" &
      "@media (prefers-color-scheme: dark) { :root { --fg: #e8e8ea; " &
      "--bg: #18181a; --line: #333338; --head: #232327; " &
      "--bad: #3a1f20; --badfg: #f2b8b5; } }\n" &
      "body { font: 14px/1.4 -apple-system, system-ui, sans-serif; " &
      "color: var(--fg); background: var(--bg); margin: 16px; }\n" &
      "table { border-collapse: collapse; margin: 8px 0 24px; " &
      "max-width: 100%; }\n" &
      "th, td { border-bottom: 1px solid var(--line); padding: 4px 10px; }\n" &
      "th { background: var(--head); text-align: right; }\n" &
      "th:first-child, td:first-child { text-align: left; }\n" &
      "td { text-align: right; font-variant-numeric: tabular-nums; }\n" &
      "tr.bad td { background: var(--bad); color: var(--badfg); }\n" &
      "</style></head><body>\n" &
      &"<h1>AWM policy stats</h1>\n<p>{games} hosted replays. Red rows: " &
      &"our value ({columns[0]}) lies clearly outside the range of the " &
      &"opponents that win more often ({referenceText}). Gap = ours minus {best}, the best opponent by " &
      "win rate.</p>\n"
  let titles = ["", "Direct: our card and target choices",
    "Indirect: what draws and energy allowed",
    "Outcomes"]
  for group in 1 .. 3:
    text.add &"\n## {titles[group]}\n\n| stat |"
    html.add &"<h2>{titles[group]}</h2>\n<table>\n<tr><th>stat</th>"
    for label in columns:
      text.add &" {label} |"
      html.add &"<th>{label}</th>"
    text.add " gap |\n|---|"
    html.add "<th>gap</th></tr>\n"
    for label in columns:
      text.add "---:|"
    text.add "---:|\n"
    for row in rows():
      if row.group != group:
        continue
      var anyValue = false
      for label in columns:
        if get(label, row.num) > 0:
          anyValue = true
      if not anyValue:
        continue
      let
        ours = value(columns[0], row)
        theirs = value(best, row)
      var
        low = Inf
        high = -Inf
      for label in reference:
        let v = value(label, row)
        if v == v:
          low = min(low, v)
          high = max(high, v)
      var bad = false
      if ours == ours and low <= high:
        let
          margin = max(low - ours, ours - high)
          scale = max(max(abs(low), abs(high)), abs(ours))
          floor = if row.scale >= 100: 2.0 else: 0.1
        bad = margin >= floor and margin >= 0.2 * scale
      var gap = ""
      if ours == ours and theirs == theirs:
        gap = formatFloat(ours - theirs, ffDecimal, row.digits)
      text.add &"| {row.title} |"
      html.add (if bad: "<tr class=\"bad\">" else: "<tr>")
      html.add &"<td>{row.title}</td>"
      for label in columns:
        text.add &" {cell(label, row)} |"
        html.add &"<td>{cell(label, row)}</td>"
      text.add &" {gap}{(if bad: \" !\" else: \"\")} |\n"
      html.add &"<td>{gap}</td></tr>\n"
    html.add "</table>\n"
  html.add "</body></html>\n"
  writeFile(output, text)
  writeFile(output.changeFileExt("html"), html)
  echo text

main()
