## Splits a paired mixed-roster score gap by our seat's teammates and opponents.
##
##   gota_mates <bodies dir> <candidate_live.tsv> <baseline_live.tsv>
##
## Prints the mean candidate-minus-baseline points per game for every
## player that sat beside (TEAMMATE) or against (OPPONENT) our seat in at
## least 12 paired games.

import
  std/[algorithm, json, os, strutils, tables]

type
  Stat = object
    count: int
    sum: float
    sumSquares: float

proc points(letter: string): float =
  ## Returns game points for one result letter.
  case letter
  of "W":
    1.0
  of "D":
    0.5
  else:
    0.0

proc load(path: string): Table[string, float] =
  ## Loads roster and seed keyed points from a live tsv.
  for line in lines(path):
    let parts = line.split('\t')
    if parts.len >= 3:
      result[parts[0] & " " & parts[1]] = points(parts[2])

proc player(policy: string): string =
  ## Returns the player part of a policy reference.
  policy.split(':')[0]

proc main() =
  ## Prints the mean gap per teammate and per opponent.
  let
    bodies = paramStr(1)
    candidate = load(paramStr(2))
    baseline = load(paramStr(3))
  var
    mates: Table[string, Stat]
    rivals: Table[string, Stat]
  for path in walkFiles(bodies / "*.json"):
    let
      body = parseFile(path)
      name = path.extractFilename.changeFileExt("")
      parts = name.split('_')
      roster = parts[^2] & "_" & parts[^1]
    var
      ourSlot = -1
      policies: array[10, string]
    for entry in body["roster"]:
      let
        slot = entry["slot"].getInt
        policy = entry["player"]["policy_ref"].getStr
      policies[slot] = policy
      if policy.startsWith("khors:"):
        ourSlot = slot
    if ourSlot < 0:
      continue
    for key, value in candidate:
      if not key.startsWith(roster & " ") or key notin baseline:
        continue
      let diff = value - baseline[key]
      for slot in 0 ..< 10:
        if slot == ourSlot:
          continue
        let
          who = player(policies[slot])
          same = (slot < 5) == (ourSlot < 5)
        if same:
          mates.mgetOrPut(who, Stat()).count += 1
          mates[who].sum += diff
          mates[who].sumSquares += diff * diff
        else:
          rivals.mgetOrPut(who, Stat()).count += 1
          rivals[who].sum += diff
          rivals[who].sumSquares += diff * diff
  for (title, table) in [("TEAMMATE", mates), ("OPPONENT", rivals)]:
    echo "== ", title, " (candidate minus baseline, per game)"
    var rows: seq[(float, string)]
    for who, stat in table:
      if stat.count >= 12:
        rows.add((stat.sum / stat.count.float, who))
    rows.sort()
    for (mean, who) in rows:
      let stat = table[who]
      echo who.alignLeft(48), " n ", ($stat.count).align(4),
        "  ", formatFloat(mean, ffDecimal, 3).align(7)

main()
