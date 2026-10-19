## Test-stage helper: prints the seeded bank trees (and other solid land)
## for one Pudge Wars map seed, so stages can pick posts and aims that
## are covered or clear. Scripts never see trees; this is analysis only.
##
##   treedump SEED [teamSize]            -> "tree x z" / "solid x z" lines
##   treedump SEED --los x0 z0 x1 z1     -> "clear" or "tree x z" first blocker
##
## Compile from sims/pudge-wars (its config.nims resolves the deps):
##   nim c -d:release --path:examples/pudge_wars -o:stages/treedump stages/treedump.nim

import std/[os, strutils, math]
import maps, content, polyworld/pathing

proc losBlock(x0, z0, x1, z1: float): (bool, int, int) =
  ## First tree/solid tile within 0.9 tiles of the segment, walking it.
  let dx = x1 - x0
  let dz = z1 - z0
  let ln = max(sqrt(dx*dx + dz*dz), 1e-6)
  var t = 0.0
  while t <= ln:
    let px = x0 + dx * t / ln
    let pz = z0 + dz * t / ln
    for ox in -1 .. 1:
      for oz in -1 .. 1:
        let tx = int(floor(px)) + ox
        let tz = int(floor(pz)) + oz
        if tx < 0 or tz < 0 or tx >= GridTiles or tz >= GridTiles: continue
        if not landTile(tx) and not islandTile(tx, tz): continue
        let cx = float(tx) + 0.5
        let cz = float(tz) + 0.5
        if (cx - px)*(cx - px) + (cz - pz)*(cz - pz) <= 0.9*0.9:
          if fieldTreeTile(tx, tz) or hookReboundTile(tx, tz) or islandTile(tx, tz):
            return (true, tx, tz)
    t += 0.25
  (false, -1, -1)

proc main() =
  if paramCount() < 1:
    quit("usage: treedump SEED [teamSize] | treedump SEED --los x0 z0 x1 z1", 2)
  let seed = int32(parseInt(paramStr(1)))
  var teamSize = 3
  var losArgs: seq[float]
  var i = 2
  while i <= paramCount():
    if paramStr(i) == "--los":
      for k in 1 .. 4: losArgs.add parseFloat(paramStr(i + k))
      i += 5
    else:
      teamSize = parseInt(paramStr(i)); inc i
  discard generateMap(seed, teamSize)
  if losArgs.len == 4:
    let (blocked, tx, tz) = losBlock(losArgs[0], losArgs[1], losArgs[2], losArgs[3])
    if blocked: echo "tree ", tx, " ", tz else: echo "clear"
    return
  for z in 0 ..< GridTiles:
    for x in 0 ..< GridTiles:
      if fieldTreeTile(x, z): echo "tree ", x, " ", z
      elif landTile(x) and hookReboundTile(x, z) and rimDist(x, z) == 0: echo "solid ", x, " ", z

main()
