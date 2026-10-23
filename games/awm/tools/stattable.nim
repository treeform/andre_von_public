## Statistical table over many replays: one column per policy (ours
## first, then the top rivals), one stat per row, grouped into what we
## control directly (plays, timing, attacks, removal targets), indirectly
## (energy, draws, Bubble uptime, Primordial survival) and outcomes (wins,
## kills, deaths, duels). Writes an HTML table with rows highlighted in
## red where our value is out of line with the rivals' mean.
##
##   stattable FOLDER OUT.html OURS RIVAL1 RIVAL2 RIVAL3

import
  std/[algorithm, math, os, strformat, strutils, tables],
  sim, replays

const Cards = ["Bubble", "Bubble Shield", "Spirit", "Bouncer", "Primordial",
  "Summon Primordial", "Control", "Oozification", "Hail of Arrows", "Study",
  "Plan", "Morphosis Chamber", "Ooze"]

type
  Acc = object
    games, wins, kills, deaths, deathTurn, turns, energyUnused: int
    reachedDuel, duelWins, duelLifeOurs, duelLifeTheirs: int
    plays: CountTable[string]
    firstTurn: CountTable[string]  ## Sum of own-turn index of first play.
    firstCount: CountTable[string]
    tossed: CountTable[string]
    heroAttacks, minionAttacks, oozeHeroAttacks, spiritMinionAttacks: int
    primSwings, primSwingsBubbled, heroNext, heroPrev, heroLowest, heroBubbled: int
    removalAtMax, removalTotal, removalAtPrim: int
    summonBiggest, summonTotal, summonPrev: int
    bubbleTurns, otherTurns: int
    primEntered, primTurnsAlive, primLeft: int
    damageDealt, damageTaken: int
    drawn: int
    handEnd, turnEnds: int
    zeroFirstTurns, bigTurns: int

proc main() =
  let
    folder = paramStr(1)
    outPath = paramStr(2)
  var names: seq[string]
  for k in 3 .. paramCount():
    names.add paramStr(k)
  var acc = initOrderedTable[string, Acc]()
  for n in names:
    acc[n] = Acc()
  proc key(label: string): string =
    for n in names:
      if n in label:
        return n
    ""
  for line in readFile(folder / "index.tsv").splitLines:
    if line.len == 0:
      continue
    let fields = line.split('\t')
    let labels = fields[2].split('|')
    let path = folder / fields[0] & ".raw"
    if not fileExists(path):
      continue
    let data = loadReplay(path)
    var game = newGame(data.header.setup)
    let n = labels.len
    var seatKey: seq[string]
    for l in labels:
      seatKey.add key(l)
    for k in seatKey:
      if k.len > 0:
        inc acc[k].games
    var
      firstPlayed = initTable[string, bool]()  # seat&card
      ownTurns = newSeq[int](n)
      deadAt = newSeq[int](n)
      primAlive = initTable[int, int]()  # minion id -> turn entered
      primOwner = initTable[int, int]()
      lastTurn = -1
      duelSeen = false
      zeroFirst = newSeq[bool](n)
      bigSeen = newSeq[bool](n)
      zeroSeen = newSeq[bool](n)
    for action in data.actions:
      let acting = action.playerId.int
      let k = seatKey[acting]
      if game.turnNumber != lastTurn:
        lastTurn = game.turnNumber
        inc ownTurns[game.currentPlayer]
        # Bubble uptime for every other living hero.
        for p in 0 ..< n:
          if p != game.currentPlayer and not game.dead(p) and seatKey[p].len > 0:
            inc acc[seatKey[p]].otherTurns
            for m in game.players[p].board:
              if m.card.name == "Bubble":
                inc acc[seatKey[p]].bubbleTurns
                break
        for p in 0 ..< n:
          zeroSeen[p] = false
          bigSeen[p] = false
      # Track Primordials entering and leaving boards.
      var nowPrims = initTable[int, int]()
      for p in 0 ..< n:
        for m in game.players[p].board:
          if m.card.name == "Primordial":
            nowPrims[m.id] = p
      if k.len > 0:
        case action.kind
        of ActionPlayCard:
          let hand = game.players[acting].hand
          if action.handIndex.int in 0 ..< hand.len:
            let name = hand[action.handIndex].name
            acc[k].plays.inc name
            if (k & name) notin firstPlayed:
              firstPlayed[k & name] = true
              acc[k].firstTurn.inc name, ownTurns[acting]
              acc[k].firstCount.inc name
            if name == "Study": acc[k].drawn += 2
            if name == "Plan": acc[k].drawn += 2
            if action.choices.len > 0:
              let c = action.choices[0]
              if name in ["Control", "Bouncer", "Oozification"] and c.kind == 3 and c.owner.int != acting:
                inc acc[k].removalTotal
                var best = -1
                for p in 0 ..< n:
                  if p != acting:
                    for m in game.players[p].board:
                      if m.card.kind == Minion: best = max(best, m.power)
                for m in game.players[c.owner.int].board:
                  if m.id == c.creatureId.int:
                    if m.power == best: inc acc[k].removalAtMax
                    if m.card.name == "Primordial": inc acc[k].removalAtPrim
              if name == "Summon Primordial" and c.kind == 2:
                inc acc[k].summonTotal
                var biggest = -1
                for p in 0 ..< n:
                  if p != acting and not game.dead(p):
                    biggest = max(biggest, game.players[p].board.len)
                if game.players[c.owner.int].board.len == biggest: inc acc[k].summonBiggest
                var prev = acting
                for step in 1 ..< n:
                  let q = (acting - step + n) mod n
                  if not game.dead(q):
                    prev = q
                    break
                if c.owner.int == prev: inc acc[k].summonPrev
        of ActionAttack:
          if action.choices.len == 1:
            let c = action.choices[0]
            var power = 0
            var aname = ""
            for m in game.players[acting].board:
              if m.id == action.attacker.int:
                power = m.power
                aname = m.card.name
            if c.kind == 2:
              inc acc[k].heroAttacks
              acc[k].damageDealt += power
              if seatKey[c.owner.int].len > 0:
                acc[seatKey[c.owner.int]].damageTaken += power
              if power == 0: inc acc[k].oozeHeroAttacks
              var bub = false
              for m in game.players[c.owner.int].board:
                if m.card.name == "Bubble": bub = true
              if bub: inc acc[k].heroBubbled
              if c.owner.int == game.nextPlayer(acting): inc acc[k].heroNext
              var prev = acting
              var lowest = 99
              for step in 1 ..< n:
                let q = (acting - step + n) mod n
                if not game.dead(q) and prev == acting:
                  prev = q
              for p in 0 ..< n:
                if p != acting and not game.dead(p):
                  lowest = min(lowest, game.players[p].life)
              if c.owner.int == prev: inc acc[k].heroPrev
              if game.players[c.owner.int].life == lowest: inc acc[k].heroLowest
              if power >= 8:
                inc acc[k].primSwings
                if bub: inc acc[k].primSwingsBubbled
                if zeroSeen[acting] and not bigSeen[acting]:
                  inc acc[k].zeroFirstTurns
                if not bigSeen[acting]:
                  inc acc[k].bigTurns
                bigSeen[acting] = true
              if power == 0: zeroSeen[acting] = true
            else:
              inc acc[k].minionAttacks
              if aname == "Spirit": inc acc[k].spiritMinionAttacks
        of ActionToss:
          let hand = game.players[acting].hand
          for idx in action.indices:
            if idx.int in 0 ..< hand.len:
              acc[k].tossed.inc hand[idx].name
        of ActionEndTurn:
          inc acc[k].turnEnds
          acc[k].energyUnused += game.players[acting].energy
          acc[k].handEnd += game.players[acting].hand.len
        else:
          discard
      if not game.applyAction(action):
        break
      # Primordial entries and exits.
      var afterPrims = initTable[int, int]()
      for p in 0 ..< n:
        for m in game.players[p].board:
          if m.card.name == "Primordial":
            afterPrims[m.id] = p
      for id, p in afterPrims:
        if id notin primAlive:
          primAlive[id] = game.turnNumber
          primOwner[id] = p
          if seatKey[p].len > 0: inc acc[seatKey[p]].primEntered
      var gone: seq[int]
      for id, t in primAlive:
        if id notin afterPrims:
          gone.add id
      for id in gone:
        let p = primOwner[id]
        if seatKey[p].len > 0:
          inc acc[seatKey[p]].primLeft
          acc[seatKey[p]].primTurnsAlive += game.turnNumber - primAlive[id]
        primAlive.del id
      for p in 0 ..< n:
        if game.dead(p) and deadAt[p] == 0:
          deadAt[p] = game.turnNumber
          if seatKey[p].len > 0:
            inc acc[seatKey[p]].deaths
            acc[seatKey[p]].deathTurn += game.turnNumber
          if seatKey[acting].len > 0 and acting != p:
            inc acc[seatKey[acting]].kills
      var alive: seq[int]
      for p in 0 ..< n:
        if not game.dead(p): alive.add p
      if alive.len == 2 and not duelSeen and not game.gameOver:
        duelSeen = true
        for p in alive:
          if seatKey[p].len > 0:
            inc acc[seatKey[p]].reachedDuel
            let other = (if alive[0] == p: alive[1] else: alive[0])
            acc[seatKey[p]].duelLifeOurs += game.players[p].life
            acc[seatKey[p]].duelLifeTheirs += game.players[other].life
    for p in 0 ..< n:
      if seatKey[p].len > 0:
        acc[seatKey[p]].turns += ownTurns[p]
        if game.winner == p:
          inc acc[seatKey[p]].wins
          if duelSeen: inc acc[seatKey[p]].duelWins
  # Rows.
  type Row = object
    group, name: string
    values: seq[float]
    pct: bool
  var rows: seq[Row]
  proc add(group, name: string, f: proc(a: Acc): float, pct = false) =
    var r = Row(group: group, name: name, pct: pct)
    for nm in names:
      r.values.add f(acc[nm])
    rows.add r
  proc g(a: Acc): float = max(a.games, 1).float
  for card in Cards:
    let c = card
    add("direct", c & " plays per game", proc(a: Acc): float = a.plays[c].float / g(a))
  for card in ["Study", "Spirit", "Bubble Shield", "Control", "Primordial", "Summon Primordial", "Bouncer"]:
    let c = card
    add("direct", c & " first played on own turn", proc(a: Acc): float = a.firstTurn[c].float / max(a.firstCount[c], 1).float)
  add("direct", "hero attacks per game", proc(a: Acc): float = a.heroAttacks.float / g(a))
  add("direct", "minion attacks per game", proc(a: Acc): float = a.minionAttacks.float / g(a))
  add("direct", "Spirit attacks on minions per game", proc(a: Acc): float = a.spiritMinionAttacks.float / g(a))
  add("direct", "Ooze (0-power) hero attacks per game", proc(a: Acc): float = a.oozeHeroAttacks.float / g(a))
  add("direct", "hero attacks at next seat %", proc(a: Acc): float = 100 * a.heroNext.float / max(a.heroAttacks, 1).float, true)
  add("direct", "hero attacks at previous seat %", proc(a: Acc): float = 100 * a.heroPrev.float / max(a.heroAttacks, 1).float, true)
  add("direct", "hero attacks at lowest life %", proc(a: Acc): float = 100 * a.heroLowest.float / max(a.heroAttacks, 1).float, true)
  add("direct", "hero attacks into a Bubble %", proc(a: Acc): float = 100 * a.heroBubbled.float / max(a.heroAttacks, 1).float, true)
  add("direct", "Primordial swings into a Bubble %", proc(a: Acc): float = 100 * a.primSwingsBubbled.float / max(a.primSwings, 1).float, true)
  add("direct", "turns a 0-power swing precedes the Primordial swing %", proc(a: Acc): float = 100 * a.zeroFirstTurns.float / max(a.bigTurns, 1).float, true)
  add("direct", "removal at the highest-power enemy minion %", proc(a: Acc): float = 100 * a.removalAtMax.float / max(a.removalTotal, 1).float, true)
  add("direct", "removal at a Primordial %", proc(a: Acc): float = 100 * a.removalAtPrim.float / max(a.removalTotal, 1).float, true)
  add("direct", "Summon at the biggest board %", proc(a: Acc): float = 100 * a.summonBiggest.float / max(a.summonTotal, 1).float, true)
  add("direct", "Summon at the previous seat %", proc(a: Acc): float = 100 * a.summonPrev.float / max(a.summonTotal, 1).float, true)
  for card in ["Bouncer", "Control", "Bubble", "Spirit", "Summon Primordial", "Primordial", "Oozification", "Hail of Arrows", "Plan", "Study"]:
    let c = card
    add("direct", c & " discarded per game", proc(a: Acc): float = a.tossed[c].float / g(a))
  add("indirect", "own turns per game", proc(a: Acc): float = a.turns.float / g(a))
  add("indirect", "energy unused per turn", proc(a: Acc): float = a.energyUnused.float / max(a.turnEnds, 1).float)
  add("indirect", "hand size at turn end", proc(a: Acc): float = a.handEnd.float / max(a.turnEnds, 1).float)
  add("indirect", "extra cards drawn per game", proc(a: Acc): float = a.drawn.float / g(a))
  add("indirect", "Bubble up at others' turn starts %", proc(a: Acc): float = 100 * a.bubbleTurns.float / max(a.otherTurns, 1).float, true)
  add("indirect", "Primordials entering our board per game", proc(a: Acc): float = a.primEntered.float / g(a))
  add("indirect", "turns a Primordial of ours stays", proc(a: Acc): float = a.primTurnsAlive.float / max(a.primLeft, 1).float)
  add("indirect", "Primordial swings per game", proc(a: Acc): float = a.primSwings.float / g(a))
  add("indirect", "hero damage dealt per game", proc(a: Acc): float = a.damageDealt.float / g(a))
  add("indirect", "hero damage taken per game", proc(a: Acc): float = a.damageTaken.float / g(a))
  add("outcome", "win %", proc(a: Acc): float = 100 * a.wins.float / g(a), true)
  add("outcome", "kills per game", proc(a: Acc): float = a.kills.float / g(a))
  add("outcome", "deaths %", proc(a: Acc): float = 100 * a.deaths.float / g(a), true)
  add("outcome", "mean death turn", proc(a: Acc): float = a.deathTurn.float / max(a.deaths, 1).float)
  add("outcome", "reached the final duel %", proc(a: Acc): float = 100 * a.reachedDuel.float / g(a), true)
  add("outcome", "duel win %", proc(a: Acc): float = 100 * a.duelWins.float / max(a.reachedDuel, 1).float, true)
  add("outcome", "own life at duel start", proc(a: Acc): float = a.duelLifeOurs.float / max(a.reachedDuel, 1).float)
  add("outcome", "rival life at duel start", proc(a: Acc): float = a.duelLifeTheirs.float / max(a.reachedDuel, 1).float)
  var html = "<!doctype html><html><head><meta charset='utf-8'><title>AWM stats</title><style>body{font-family:Georgia,serif;margin:24px;color:#222}table{border-collapse:collapse}th,td{padding:3px 10px;text-align:right;border-bottom:1px solid #ddd}th{text-align:right}td:first-child,th:first-child{text-align:left}tr.out td{background:#f6dcdc}tr.group td{background:#eee;font-weight:bold;text-align:left}caption{text-align:left;margin-bottom:8px}</style></head><body>"
  html.add &"<table><caption>AWM stats over {acc[names[0]].games} games of {names[0]} (folder {folder}). Red rows: ours differs from the rivals' mean by more than 30%.</caption><tr><th>stat</th>"
  for nm in names:
    html.add &"<th>{nm}</th>"
  html.add "</tr>"
  var group = ""
  var text = ""
  for r in rows:
    if r.group != group:
      group = r.group
      html.add &"<tr class='group'><td colspan='{names.len + 1}'>{group}</td></tr>"
      text.add "== " & group & "\n"
    var mean = 0.0
    for i in 1 ..< r.values.len:
      mean += r.values[i]
    mean /= max(r.values.len - 1, 1).float
    let ours = r.values[0]
    let offLine = r.group != "outcome" and abs(ours - mean) > 0.3 * max(abs(mean), 0.5)
    html.add (if offLine: "<tr class='out'>" else: "<tr>")
    html.add &"<td>{r.name}</td>"
    var line = (if offLine: "* " else: "  ") & r.name & ":"
    for v in r.values:
      html.add (if r.pct: &"<td>{v:.0f}%</td>" else: &"<td>{v:.2f}</td>")
      line.add (if r.pct: &" {v:.0f}%" else: &" {v:.2f}")
    html.add "</tr>"
    text.add line & "\n"
  html.add "</table></body></html>"
  writeFile(outPath, html)
  echo text

main()
