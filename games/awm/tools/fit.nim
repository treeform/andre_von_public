## Scores how well a script predicts a rival's recorded decisions: at every
## decision the rival made in the hosted replays, the script runs on the
## same state and its action is compared with the record.
##
##   fit FOLDER LABEL_SUBSTRING SCRIPT.bas
##
## Prints agreement per action kind and the most common disagreements.

import
  std/[algorithm, os, strformat, strutils, tables],
  sim, bots, replays

proc heroText(game: GameState, seat, owner: int): string =
  ## Describes a hero target by its relation to the actor: seat offset,
  ## whether it has the least life among living opponents, and Bubbles.
  let n = game.playerCount
  var lowest = 99
  for p in 0 ..< n:
    if p != seat and not game.dead(p):
      lowest = min(lowest, game.players[p].life)
  var bubbles = 0
  for m in game.players[owner].board:
    if m.card.name == "Bubble":
      inc bubbles
  result = "hero"
  if owner == game.nextPlayer(seat): result.add "-next"
  elif (owner + 1) mod n == seat or game.nextPlayer(owner) == seat: result.add "-prev"
  else: result.add "-far"
  if game.players[owner].life == lowest: result.add "-weakest"
  if bubbles > 0: result.add "-bubbled"

proc describe(game: GameState, seat: int, action: ReplayAction): string =
  ## A short text for an action: the card or attacker and its first target.
  case action.kind
  of ActionPlayCard:
    let hand = game.players[seat].hand
    result = "play "
    if action.handIndex.int in 0 ..< hand.len:
      result.add hand[action.handIndex].name
    if action.choices.len > 0:
      let c = action.choices[0]
      case c.kind
      of 2: result.add " @" & game.heroText(seat, c.owner.int)
      of 3:
        for m in game.players[c.owner.int].board:
          if m.id == c.creatureId.int:
            result.add " @" & m.card.name
      of 4: result.add " @opt" & $c.option
      else: result.add " @none"
  of ActionAttack:
    result = "attack "
    for m in game.players[seat].board:
      if m.id == action.attacker.int:
        result.add m.card.name
    if action.choices.len > 0:
      let c = action.choices[0]
      if c.kind == 2:
        result.add " @" & game.heroText(seat, c.owner.int)
      else:
        result.add " @minion"
        for m in game.players[c.owner.int].board:
          if m.id == c.creatureId.int:
            result.add ":" & m.card.name
  of ActionEndTurn: result = "end"
  of ActionResolveTrigger: result = "trigger"
  of ActionToss: result = "toss"
  else: result = "?"

proc same(game: GameState, seat: int, a, b: ReplayAction): bool =
  ## Whether two actions are the same decision (card names, not indexes).
  if a.kind != b.kind:
    return false
  case a.kind
  of ActionPlayCard:
    let hand = game.players[seat].hand
    if a.handIndex.int notin 0 ..< hand.len or b.handIndex.int notin 0 ..< hand.len:
      return false
    if hand[a.handIndex].name != hand[b.handIndex].name:
      return false
    if a.choices.len != b.choices.len:
      return false
    for i in 0 ..< a.choices.len:
      if a.choices[i] != b.choices[i]:
        return false
    true
  of ActionAttack:
    var nameA, nameB: string
    for m in game.players[seat].board:
      if m.id == a.attacker.int: nameA = m.card.name
      if m.id == b.attacker.int: nameB = m.card.name
    if nameA != nameB or a.choices.len != b.choices.len or a.choices.len == 0:
      return false
    let ca = a.choices[0]
    let cb = b.choices[0]
    ca.kind == cb.kind and ca.owner == cb.owner and
      (ca.kind != 3 or ca.creatureId == cb.creatureId)
  of ActionToss:
    a.indices == b.indices
  of ActionResolveTrigger:
    a.choices == b.choices
  else:
    true

proc main() =
  ## Runs the fit over the folder.
  let
    folder = paramStr(1)
    who = paramStr(2)
    source = readFile(paramStr(3))
  var
    total, matched: CountTable[string]
    mismatches: CountTable[string]
    failures = 0
    games = 0
  for line in readFile(folder / "index.tsv").splitLines:
    if line.len == 0:
      continue
    let fields = line.split('\t')
    let labels = fields[2].split('|')
    let path = folder / fields[0] & ".raw"
    if not fileExists(path):
      continue
    var seats: seq[int]
    for seat, label in labels:
      if who in label:
        seats.add seat
    if seats.len == 0:
      continue
    inc games
    let data = loadReplay(path)
    resetInboxes(labels.len)
    var vms = initTable[int, BotVm]()
    for seat in seats:
      vms[seat] = loadBot(source, seat.int32)
      vms[seat].seedBot(data.header.setup.seed.int64)
    var game = newGame(data.header.setup)
    for action in data.actions:
      let acting = action.playerId.int
      if acting in vms:
        var probe = game
        let kind = describe(game, acting, action).split(' ')[0]
        total.inc kind
        if vms[acting].runDecision(probe, apply = false) == BotFailed:
          inc failures
          mismatches.inc describe(game, acting, action) & " -> FAILED " &
            vms[acting].lastError[0 ..< min(40, vms[acting].lastError.len)]
        elif same(game, acting, action, vms[acting].action):
          matched.inc kind
        else:
          mismatches.inc describe(game, acting, action) & " -> " &
            describe(game, acting, vms[acting].action)
      if not game.applyAction(action):
        break
  echo &"{games} games, failures {failures}"
  var all, allMatched = 0
  for kind, n in total:
    all += n
    allMatched += matched[kind]
    echo &"  {kind}: {matched[kind]}/{n} ({100.0 * matched[kind].float / n.float:.1f}%)"
  echo &"  all: {allMatched}/{all} ({100.0 * allMatched.float / max(all, 1).float:.1f}%)"
  var pairs: seq[(string, int)]
  for text, n in mismatches:
    pairs.add (text, n)
  pairs.sort(proc(a, b: (string, int)): int = b[1] - a[1])
  for i in 0 ..< min(25, pairs.len):
    echo &"  {pairs[i][1]:4} {pairs[i][0]}"

main()
