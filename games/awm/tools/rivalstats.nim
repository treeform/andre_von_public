## Extracts how every league policy plays from hosted replays: deck, class,
## cards played per game, attack targeting, deaths and kills.
##
##   rivalstats eps/league/replays_recent [POLICY_FILTER]
##
## The folder holds `index.tsv` (episode id, replay url, seat labels joined
## by |, seat scores joined by |) and one gunzipped `<episode id>.raw` per
## game. Policies are named by their label (name:vN).

import
  std/[algorithm, os, strformat, strutils, tables],
  sim, replays

type
  Stats = object
    games, wins, seats: int
    deck: string
    heroClass: string
    plays: CountTable[string]
    attacks, heroAttacks, minionAttacks: int
    lowestLifeHits, nextSeatHits, prevSeatHits: int
    offsetHits: array[7, int]
    deathTurn, deaths, damageDeaths, deckDeaths: int
    killedBy: CountTable[string]
    kills: int
    turnsPlayed: int
    energyUnused: int
    deathsByAlive: array[8, int]  ## Living players (incl. us) when we died.

proc main() =
  ## Walks every replay and prints per-policy tallies.
  if paramCount() < 1:
    quit("Usage: rivalstats FOLDER [POLICY_FILTER]", 1)
  let
    folder = paramStr(1)
    filter = if paramCount() >= 2: paramStr(2) else: ""
  var stats = initOrderedTable[string, Stats]()
  for line in readFile(folder / "index.tsv").splitLines:
    if line.len == 0:
      continue
    let fields = line.split('\t')
    let
      id = fields[0]
      labels = fields[2].split('|')
    let path = folder / id & ".raw"
    if not fileExists(path):
      continue
    let data = loadReplay(path)
    let setup = data.header.setup
    if setup.classes.len != labels.len:
      echo id, " seat count mismatch"
      continue
    var game = newGame(setup)
    for seat, label in labels:
      if label notin stats:
        stats[label] = Stats()
      inc stats[label].seats
      var deck: seq[string]
      for card in setup.decks[seat]:
        deck.add card.name & "x" & $card.copies
      stats[label].deck = deck.join(",")
      stats[label].heroClass = $setup.heroClasses[seat]
    var deadAt = newSeq[int](labels.len)
    var lastTurnPlayer = -1
    for action in data.actions:
      let acting = action.playerId.int
      let label = labels[acting]
      if action.kind == ActionPlayCard:
        let hand = game.players[acting].hand
        if action.handIndex.int in 0 ..< hand.len:
          stats[label].plays.inc hand[action.handIndex].name
      elif action.kind == ActionAttack and action.choices.len == 1:
        let target = action.choices[0]
        inc stats[label].attacks
        let owner = target.owner.int
        if target.kind == HeroChoice.ord.uint8:
          inc stats[label].heroAttacks
          var lowest = true
          for p in 0 ..< game.playerCount:
            if p != acting and not game.dead(p) and
                game.players[p].life < game.players[owner].life:
              lowest = false
          if lowest:
            inc stats[label].lowestLifeHits
          let offset = (owner - acting + game.playerCount) mod game.playerCount
          inc stats[label].offsetHits[offset]
          if owner == game.nextPlayer(acting):
            inc stats[label].nextSeatHits
          var prev = acting
          for step in 1 ..< game.playerCount:
            let candidate = (acting - step + game.playerCount) mod game.playerCount
            if not game.dead(candidate):
              prev = candidate
              break
          if owner == prev:
            inc stats[label].prevSeatHits
        else:
          inc stats[label].minionAttacks
      elif action.kind == ActionEndTurn:
        inc stats[label].turnsPlayed
        stats[label].energyUnused += game.players[acting].energy
      if not game.applyAction(action):
        echo id, " refused action at tick ", action.tick
        break
      for p in 0 ..< game.playerCount:
        if game.dead(p) and deadAt[p] == 0:
          deadAt[p] = game.turnNumber
          inc stats[labels[p]].deaths
          stats[labels[p]].deathTurn += game.turnNumber
          var alive = 0
          for q in 0 ..< game.playerCount:
            if not game.dead(q):
              inc alive
          inc stats[labels[p]].deathsByAlive[min(7, alive + 1)]
          if game.players[p].drewFromEmpty:
            inc stats[labels[p]].deckDeaths
          else:
            inc stats[labels[p]].damageDeaths
            stats[labels[p]].killedBy.inc labels[acting]
            if acting != p:
              inc stats[label].kills
    for seat, label in labels:
      inc stats[label].games
      if game.winner == seat:
        inc stats[label].wins
  for label, s in stats:
    if filter.len > 0 and filter notin label:
      continue
    echo &"== {label}: {s.wins}/{s.games} wins, {s.heroClass}, deck {s.deck}"
    let g = max(s.games, 1).float
    echo &"   attacks/game {s.attacks.float / g:.1f}: hero {s.heroAttacks} minion {s.minionAttacks};",
      &" of hero hits lowest-life {s.lowestLifeHits} next-seat {s.nextSeatHits} prev-seat {s.prevSeatHits} offsets {s.offsetHits[1 .. 4]}"
    echo &"   deaths {s.deaths} (damage {s.damageDeaths}, deck {s.deckDeaths}) mean death turn {s.deathTurn.float / max(s.deaths, 1).float:.1f};",
      &" kills {s.kills}; turns/game {s.turnsPlayed.float / g:.1f} unused energy/turn {s.energyUnused.float / max(s.turnsPlayed, 1).float:.2f}"
    var plays: seq[(string, int)]
    for name, count in s.plays:
      plays.add (name, count)
    plays.sort(proc(a, b: (string, int)): int = b[1] - a[1])
    var text = ""
    for (name, count) in plays:
      text.add &" {name} {count.float / g:.2f}"
    echo "   plays/game:", text
    echo "   deaths by players alive at death (2..5): ", s.deathsByAlive[2 .. 5]
    var killers: seq[(string, int)]
    for name, count in s.killedBy:
      killers.add (name, count)
    killers.sort(proc(a, b: (string, int)): int = b[1] - a[1])
    echo "   killed by: ", killers

main()
