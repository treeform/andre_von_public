## The final duels of one policy in hosted replays: who the opponent was,
## life totals and boards when the duel began, how long it lasted, who
## won, and what each side did in it.
##
##   duels FOLDER LABEL_SUBSTRING

import
  std/[algorithm, os, strformat, strutils, tables],
  sim, replays

type
  Duel = object
    opponent: string
    ourLife, theirLife, ourBoard, theirBoard, ourPrimordials, theirPrimordials: int
    ourBubbles, theirBubbles, ourHand, theirHand, ourEnergy, theirEnergy: int
    turns: int
    won: bool
    firstMover: bool  ## We acted first in the duel.
    ourPlays, theirPlays: CountTable[string]
    ourMinionAttacks, theirMinionAttacks, ourBubbleHits, theirBubbleHits: int

proc count(game: GameState, p: int, name: string): int =
  for m in game.players[p].board:
    if m.card.name == name:
      inc result

proc main() =
  let
    folder = paramStr(1)
    who = paramStr(2)
  var duels: seq[Duel]
  for line in readFile(folder / "index.tsv").splitLines:
    if line.len == 0:
      continue
    let fields = line.split('\t')
    let labels = fields[2].split('|')
    let path = folder / fields[0] & ".raw"
    if not fileExists(path):
      continue
    var us = -1
    for seat, label in labels:
      if who in label:
        us = seat
    if us < 0:
      continue
    let data = loadReplay(path)
    var game = newGame(data.header.setup)
    var duel: Duel
    var inDuel = false
    var them = -1
    var startTurn = 0
    for action in data.actions:
      let acting = action.playerId.int
      if inDuel:
        let mine = acting == us
        if action.kind == ActionPlayCard:
          let hand = game.players[acting].hand
          if action.handIndex.int in 0 ..< hand.len:
            if mine: duel.ourPlays.inc hand[action.handIndex].name
            else: duel.theirPlays.inc hand[action.handIndex].name
        elif action.kind == ActionAttack and action.choices.len == 1:
          let c = action.choices[0]
          if c.kind == 3:
            if mine: inc duel.ourMinionAttacks else: inc duel.theirMinionAttacks
          elif c.kind == 2 and game.count(c.owner.int, "Bubble") > 0:
            if mine: inc duel.ourBubbleHits else: inc duel.theirBubbleHits
      if not game.applyAction(action):
        break
      var alive: seq[int]
      for p in 0 ..< game.playerCount:
        if not game.dead(p):
          alive.add p
      if not inDuel and alive.len == 2 and us in alive and not game.gameOver:
        inDuel = true
        them = (if alive[0] == us: alive[1] else: alive[0])
        startTurn = game.turnNumber
        duel.opponent = labels[them].split(':')[0]
        duel.ourLife = game.players[us].life
        duel.theirLife = game.players[them].life
        duel.ourBoard = game.players[us].board.len
        duel.theirBoard = game.players[them].board.len
        duel.ourPrimordials = game.count(us, "Primordial")
        duel.theirPrimordials = game.count(them, "Primordial")
        duel.ourBubbles = game.count(us, "Bubble")
        duel.theirBubbles = game.count(them, "Bubble")
        duel.ourHand = game.players[us].hand.len
        duel.theirHand = game.players[them].hand.len
        duel.ourEnergy = game.players[us].totalEnergy
        duel.theirEnergy = game.players[them].totalEnergy
        duel.firstMover = game.currentPlayer == us
      if inDuel and game.gameOver:
        duel.turns = game.turnNumber - startTurn
        duel.won = game.winner == us
        duels.add duel
        inDuel = false
    if inDuel and not game.gameOver:
      duel.turns = game.turnNumber - startTurn
      duel.won = false
      duel.opponent.add "(timeout)"
      duels.add duel
  echo &"{duels.len} duels for {who}"
  var byOpp = initOrderedTable[string, (int, int)]()
  var firstWon, firstN, lifeLead, lifeLeadWon, lifeTrail, lifeTrailWon = 0
  var sumLife, sumTheirLife, sumPrim, sumTheirPrim, sumBub, sumTheirBub, sumTurns = 0
  var ourPlays, theirPlays: CountTable[string]
  var ourMinion, theirMinion, ourBub, theirBub = 0
  for d in duels:
    var e = byOpp.getOrDefault(d.opponent)
    inc e[1]
    if d.won: inc e[0]
    byOpp[d.opponent] = e
    if d.firstMover:
      inc firstN
      if d.won: inc firstWon
    if d.ourLife > d.theirLife:
      inc lifeLead
      if d.won: inc lifeLeadWon
    elif d.ourLife < d.theirLife:
      inc lifeTrail
      if d.won: inc lifeTrailWon
    sumLife += d.ourLife; sumTheirLife += d.theirLife
    sumPrim += d.ourPrimordials; sumTheirPrim += d.theirPrimordials
    sumBub += d.ourBubbles; sumTheirBub += d.theirBubbles
    sumTurns += d.turns
    for k, v in d.ourPlays: ourPlays.inc k, v
    for k, v in d.theirPlays: theirPlays.inc k, v
    ourMinion += d.ourMinionAttacks; theirMinion += d.theirMinionAttacks
    ourBub += d.ourBubbleHits; theirBub += d.theirBubbleHits
  let n = max(duels.len, 1).float
  for opp, e in byOpp:
    echo &"  vs {opp}: won {e[0]}/{e[1]}"
  echo &"  we act first: won {firstWon}/{firstN}; we act second: won {duels.len - firstN - (firstN - firstWon) - (duels.len - firstN - (duels.len - firstN)) + 0}"
  echo &"  life lead at start: won {lifeLeadWon}/{lifeLead}; life trail: won {lifeTrailWon}/{lifeTrail}"
  echo &"  mean at start: our life {sumLife.float / n:.1f} theirs {sumTheirLife.float / n:.1f}; our Primordials {sumPrim.float / n:.2f} theirs {sumTheirPrim.float / n:.2f}; our Bubbles {sumBub.float / n:.2f} theirs {sumTheirBub.float / n:.2f}; duel turns {sumTurns.float / n:.1f}"
  proc top(t: CountTable[string]): string =
    var pairs: seq[(string, int)]
    for k, v in t: pairs.add (k, v)
    pairs.sort(proc(a, b: (string, int)): int = b[1] - a[1])
    for (k, v) in pairs: result.add &" {k} {v.float / n:.2f}"
  echo "  our plays/duel:", top(ourPlays)
  echo "  their plays/duel:", top(theirPlays)
  echo &"  minion attacks/duel: ours {ourMinion.float / n:.1f} theirs {theirMinion.float / n:.1f}; hero attacks into Bubbles: ours {ourBub.float / n:.1f} theirs {theirBub.float / n:.1f}"

main()
