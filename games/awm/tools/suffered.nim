## What one policy suffers in hosted replays: hero damage by attacker card
## and by rival, removal spells aimed at its minions, Summon Primordials
## aimed at its hero, and its own attacks that hit a Bubble.
##
##   suffered FOLDER LABEL_SUBSTRING

import
  std/[algorithm, os, strformat, strutils, tables],
  sim, replays

proc main() =
  let
    folder = paramStr(1)
    who = paramStr(2)
  var
    damageByCard, damageByRival, spellsAtUs, spellsByRival: CountTable[string]
    bubbleHits, attacksTotal, games = 0
    landed, absorbed = 0
    receivedByPower: array[4, int]  ## Attacks at our hero by attacker power 0, 1, 2-9, 10+.
    absorbedByPower: array[4, int]
    damageByTurnBand: array[8, int]
  for line in readFile(folder / "index.tsv").splitLines:
    if line.len == 0:
      continue
    let fields = line.split('\t')
    let labels = fields[2].split('|')
    let path = folder / fields[0] & ".raw"
    if not fileExists(path):
      continue
    var ours: seq[int]
    for seat, label in labels:
      if who in label:
        ours.add seat
    if ours.len == 0:
      continue
    inc games
    let data = loadReplay(path)
    var game = newGame(data.header.setup)
    for action in data.actions:
      let acting = action.playerId.int
      if action.kind == ActionAttack and action.choices.len == 1:
        let c = action.choices[0]
        if c.kind == 2 and c.owner.int in ours and acting notin ours:
          var power = 0
          var name = "?"
          for m in game.players[acting].board:
            if m.id == action.attacker.int:
              power = m.power
              name = m.card.name
          damageByCard.inc name, power
          damageByRival.inc labels[acting], power
          damageByTurnBand[min(7, game.turnNumber div 10)] += power
          var shielded = false
          for m in game.players[c.owner.int].board:
            if m.card.name == "Bubble":
              shielded = true
          let bucket = if power == 0: 0 elif power == 1: 1 elif power < 10: 2 else: 3
          inc receivedByPower[bucket]
          if shielded:
            absorbed += power
            inc absorbedByPower[bucket]
          else:
            landed += power
        elif acting in ours and c.kind == 2:
          inc attacksTotal
          for m in game.players[c.owner.int].board:
            if m.card.name == "Bubble":
              inc bubbleHits
              break
      elif action.kind == ActionPlayCard and acting notin ours:
        let hand = game.players[acting].hand
        if action.handIndex.int in 0 ..< hand.len and action.choices.len > 0:
          let c = action.choices[0]
          if (c.kind == 2 or c.kind == 3) and c.owner.int in ours:
            spellsAtUs.inc hand[action.handIndex].name
            spellsByRival.inc labels[acting]
      if not game.applyAction(action):
        break
  proc show(title: string, t: CountTable[string]) =
    var pairs: seq[(string, int)]
    for k, v in t:
      pairs.add (k, v)
    pairs.sort(proc(a, b: (string, int)): int = b[1] - a[1])
    echo title, ": ", pairs
  echo &"{games} games for {who}"
  show("hero damage by attacker card", damageByCard)
  show("hero damage by rival", damageByRival)
  echo "hero damage by turn band (x10): ", damageByTurnBand
  show("cards aimed at us (minion or hero targets)", spellsAtUs)
  show("by rival", spellsByRival)
  echo &"our hero attacks {attacksTotal}, into a Bubble {bubbleHits}"
  echo &"damage at us: landed {landed} absorbed by Bubbles {absorbed}; attacks received by power 0/1/2-9/10+ {receivedByPower} of which into a Bubble {absorbedByPower}"

main()
