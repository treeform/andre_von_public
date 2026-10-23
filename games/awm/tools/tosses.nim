## How a rival discards: at every toss decision, which card names were in
## hand and which were discarded, so a discard rule can be read off.
##
##   tosses FOLDER LABEL_SUBSTRING

import
  std/[algorithm, os, strformat, strutils, tables],
  sim, replays

proc main() =
  let
    folder = paramStr(1)
    who = paramStr(2)
  var inHand, tossed: CountTable[string]
  var costTossed, costHeld: CountTable[int]
  var decisions = 0
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
      if action.kind == ActionToss and who in labels[acting]:
        inc decisions
        let hand = game.players[acting].hand
        for i, card in hand:
          inHand.inc card.name
          if i.int32 in action.indices:
            tossed.inc card.name
            costTossed.inc card.energyCost
          else:
            costHeld.inc card.energyCost
      if not game.applyAction(action):
        break
  echo &"{decisions} toss decisions for {who}"
  var rows: seq[(string, int, int)]
  for name, n in inHand:
    rows.add (name, tossed[name], n)
  rows.sort(proc(a, b: (string, int, int)): int =
    cmp(b[1].float / b[2].float, a[1].float / a[2].float))
  for (name, t, n) in rows:
    echo &"  {name}: tossed {t} of {n} in hand ({100.0 * t.float / n.float:.0f}%)"
  echo "by cost: tossed ", costTossed, " held ", costHeld

main()
