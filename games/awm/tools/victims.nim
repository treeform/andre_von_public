## Why enemy Primordials pick their victims: for every hero attack by a
## minion of power 8 or more, the victim's relation to the attacker (next
## seat, previous seat, elsewhere), whether the victim was bubbled, the
## victim's life rank, and how many other heroes were unbubbled. Tallied
## per victim policy and per attacker policy.
##
##   victims FOLDER

import
  std/[algorithm, os, strformat, strutils, tables],
  sim, replays

type
  Tally = object
    hits, asNext, asPrev, bubbled, lowest, others, othersUnbubbled: int
    heroTurns, bubbledTurns: int  ## Turn starts of other players while alive: Bubble uptime.

proc main() =
  let folder = paramStr(1)
  var byVictim = initOrderedTable[string, Tally]()
  var byAttacker = initOrderedTable[string, Tally]()
  for line in readFile(folder / "index.tsv").splitLines:
    if line.len == 0:
      continue
    let fields = line.split('\t')
    var labels = fields[2].split('|')
    for l in labels.mitems:
      l = l.split(':')[0]
    let path = folder / fields[0] & ".raw"
    if not fileExists(path):
      continue
    let data = loadReplay(path)
    var game = newGame(data.header.setup)
    var lastTurn = -1
    for action in data.actions:
      let acting = action.playerId.int
      if game.turnNumber != lastTurn:
        lastTurn = game.turnNumber
        # Bubble uptime: at every turn start, every other living hero.
        for p in 0 ..< game.playerCount:
          if p != game.currentPlayer and not game.dead(p):
            var t = byVictim.getOrDefault(labels[p])
            inc t.heroTurns
            for m in game.players[p].board:
              if m.card.name == "Bubble":
                inc t.bubbledTurns
                break
            byVictim[labels[p]] = t
      if action.kind == ActionAttack and action.choices.len == 1 and
          action.choices[0].kind == 2:
        var power = 0
        for m in game.players[acting].board:
          if m.id == action.attacker.int:
            power = m.power
        if power >= 8:
          let victim = action.choices[0].owner.int
          var lowest = 99
          var others, othersUnbubbled = 0
          for p in 0 ..< game.playerCount:
            if p != acting and not game.dead(p):
              lowest = min(lowest, game.players[p].life)
              if p != victim:
                inc others
                var bub = false
                for m in game.players[p].board:
                  if m.card.name == "Bubble": bub = true
                if not bub: inc othersUnbubbled
          var victimBubbled = false
          for m in game.players[victim].board:
            if m.card.name == "Bubble": victimBubbled = true
          var prev = acting
          for step in 1 ..< game.playerCount:
            let c = (acting - step + game.playerCount) mod game.playerCount
            if not game.dead(c):
              prev = c
              break
          proc mark(t: var Tally) =
            inc t.hits
            if victim == game.nextPlayer(acting): inc t.asNext
            if victim == prev: inc t.asPrev
            if victimBubbled: inc t.bubbled
            if game.players[victim].life == lowest: inc t.lowest
            t.others += others
            t.othersUnbubbled += othersUnbubbled
          var tv = byVictim.getOrDefault(labels[victim])
          mark(tv)
          byVictim[labels[victim]] = tv
          var ta = byAttacker.getOrDefault(labels[acting])
          mark(ta)
          byAttacker[labels[acting]] = ta
      if not game.applyAction(action):
        break
  echo "Primordial (power >= 8) hero hits BY VICTIM:"
  for name, t in byVictim:
    let n = max(t.hits, 1).float
    echo &"  {name}: hits {t.hits}; as attacker's next {t.asNext} ({100 * t.asNext.float / n:.0f}%) prev {t.asPrev} ({100 * t.asPrev.float / n:.0f}%);",
      &" bubbled {t.bubbled} ({100 * t.bubbled.float / n:.0f}%); lowest life {t.lowest} ({100 * t.lowest.float / n:.0f}%);",
      &" other heroes unbubbled {t.othersUnbubbled}/{t.others}; Bubble uptime at others' turns {100 * t.bubbledTurns.float / max(t.heroTurns, 1).float:.0f}%"
  echo "BY ATTACKER:"
  for name, t in byAttacker:
    let n = max(t.hits, 1).float
    echo &"  {name}: hits {t.hits}; victim next {100 * t.asNext.float / n:.0f}% prev {100 * t.asPrev.float / n:.0f}% bubbled {100 * t.bubbled.float / n:.0f}% lowest {100 * t.lowest.float / n:.0f}%"

main()
