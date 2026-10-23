## Tests hypotheses about one rival's targeting across hosted replays:
## which hero its minions attack, which hero its Summon Primordial picks,
## and which minion its Control, Oozification and Bouncer pick.
##
##   rivallogic FOLDER LABEL_SUBSTRING

import
  std/[os, strformat, strutils, tables],
  sim, replays

type
  Tally = object
    total, nextSeat, minLife, minLifeUnbubbled, noBubble, maxBoard,
      maxMinions, prevSeat, maxPower, lethal: int

proc bubbles(game: GameState, p: int): int =
  for m in game.players[p].board:
    if m.card.name == "Bubble":
      inc result

proc minions(game: GameState, p: int): int =
  for m in game.players[p].board:
    if m.card.kind == Minion:
      inc result

proc main() =
  ## Walks the replays and prints the hypothesis hit rates.
  let
    folder = paramStr(1)
    who = paramStr(2)
  var
    attacks, summons: Tally
    picks = initTable[string, Tally]()
    plays = initOrderedTable[string, Table[int, int]]()  # card -> energy at play
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
    for action in data.actions:
      let acting = action.playerId.int
      if who in labels[acting]:
        let me = acting
        var
          living: seq[int]
          lowest = 99
          lowestUnbubbled = 99
          biggestBoard = -1
          mostMinions = -1
        for p in 0 ..< game.playerCount:
          if p != me and not game.dead(p):
            living.add p
            lowest = min(lowest, game.players[p].life)
            if game.bubbles(p) == 0:
              lowestUnbubbled = min(lowestUnbubbled, game.players[p].life)
            biggestBoard = max(biggestBoard, game.players[p].board.len)
            mostMinions = max(mostMinions, game.minions(p))
        let next = game.nextPlayer(me)
        var prev = me
        for step in 1 ..< game.playerCount:
          let c = (me - step + game.playerCount) mod game.playerCount
          if not game.dead(c):
            prev = c
            break
        proc judge(t: var Tally, owner: int, power = 0) =
          inc t.total
          if owner == next: inc t.nextSeat
          if owner == prev: inc t.prevSeat
          if game.players[owner].life == lowest: inc t.minLife
          if game.bubbles(owner) == 0: inc t.noBubble
          if game.bubbles(owner) == 0 and game.players[owner].life == lowestUnbubbled:
            inc t.minLifeUnbubbled
          if game.players[owner].board.len == biggestBoard: inc t.maxBoard
          if game.minions(owner) == mostMinions: inc t.maxMinions
          if power >= game.players[owner].life: inc t.lethal
        if action.kind == ActionAttack and action.choices.len == 1 and
            action.choices[0].kind == 2:
          var power = 0
          for m in game.players[me].board:
            if m.id == action.attacker.int:
              power = m.power
          judge(attacks, action.choices[0].owner.int, power)
        elif action.kind == ActionPlayCard:
          let hand = game.players[me].hand
          if action.handIndex.int in 0 ..< hand.len:
            let name = hand[action.handIndex].name
            if name notin plays:
              plays[name] = initTable[int, int]()
            plays[name].mgetOrPut(game.players[me].energy, 0) += 1
            if action.choices.len >= 1:
              let c = action.choices[0]
              if c.kind == 2 and living.len > 1:
                judge(summons, c.owner.int)
              elif c.kind == 3 and c.owner.int != me:
                # Was it the biggest-power enemy minion?
                var best = -1
                for p in living:
                  for m in game.players[p].board:
                    if m.card.kind == Minion:
                      best = max(best, m.power)
                var chosen = -1
                for m in game.players[c.owner.int].board:
                  if m.id == c.creatureId.int:
                    chosen = m.power
                var t = picks.getOrDefault(name)
                inc t.total
                if chosen == best: inc t.maxPower
                if c.owner.int == next: inc t.nextSeat
                if c.owner.int == prev: inc t.prevSeat
                picks[name] = t
      if not game.applyAction(action):
        break
  proc show(name: string, t: Tally) =
    echo &"{name}: n {t.total} next {t.nextSeat} prev {t.prevSeat} minLife {t.minLife}",
      &" minLifeUnbubbled {t.minLifeUnbubbled} noBubble {t.noBubble}",
      &" maxBoard {t.maxBoard} maxMinions {t.maxMinions} lethal {t.lethal}"
  show("hero attacks (living > 1 opponents incl.)", attacks)
  show("hero-target spells", summons)
  for name, t in picks:
    echo &"{name} minion targets: n {t.total} maxPower {t.maxPower} next {t.nextSeat} prev {t.prevSeat}"
  for name, byEnergy in plays:
    var text = ""
    for e in 0 .. 12:
      if e in byEnergy:
        text.add &" e{e}:{byEnergy[e]}"
    echo "play ", name, text

main()
