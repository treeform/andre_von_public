## Isolation tests for the scripted engine on synthetic observations: no
## game, no score. Each scenario checks one rule fires as designed.
##
##   nim r scripted_test.nim

import ../scripted

const
  Cols = 15
  TileBytes = 10
  CenterRow = 5
  CenterCol = 7
  ScalarsOffset = 1650

proc blank(comb, prof, hp: int): seq[uint8] =
  ## Open grass everywhere, given levels, healthy unless told otherwise.
  result = newSeq[uint8](ObservationSize)
  result[ScalarsOffset + 1] = uint8(comb)
  result[ScalarsOffset + 5] = uint8(hp)
  result[ScalarsOffset + 6] = 99
  result[ScalarsOffset + 7] = uint8(prof)

proc putEnemy(obs: var seq[uint8], r, c, delta, hpBucket: int) =
  let base = (r * Cols + c) * TileBytes
  obs[base + 4] = 2
  obs[base + 6] = uint8(delta)
  obs[base + 7] = uint8(hpBucket)

proc putItem(obs: var seq[uint8], r, c, kind, tier: int) =
  let base = (r * Cols + c) * TileBytes
  obs[base + 2] = uint8(kind)
  obs[base + 3] = uint8(tier - 1)

proc holdTool(obs: var seq[uint8], tier: int) =
  obs[ScalarsOffset + 13 + 3] = uint8(17 * (tier - 1) + 6)
  obs[ScalarsOffset + 18] = uint8(17 * (tier - 1) + 6)   # in slot 0
  obs[ScalarsOffset + 30] = 1

proc main() =
  # 1. Same-level enemy adjacent: attack.
  var m = newMind(1, 0)
  var obs = blank(5, 5, 90)
  obs.putEnemy(CenterRow, CenterCol + 1, 0, 2)
  doAssert m.decide(obs, 0) == 5, "attack a wounded same-level adjacent enemy"
  # 2. Much stronger enemy adjacent: run away (left, since it is right).
  m = newMind(1, 0)
  obs = blank(5, 5, 90)
  obs.putEnemy(CenterRow, CenterCol + 1, 2, 4)
  let flee = m.decide(obs, 0)
  doAssert flee >= 22 and flee <= 25, "run from a strong enemy, got " & $flee
  doAssert m.flees == 1
  # 3. Strong enemy on our row four tiles away (bow lane): leave the lane.
  m = newMind(1, 0)
  obs = blank(5, 5, 90)
  obs.putEnemy(CenterRow, CenterCol + 4, 2, 4)
  let dodge = m.decide(obs, 0)
  doAssert dodge in [0, 1, 22, 23, 25], "leave the lane or its range, got " & $dodge
  # 4. Low hp with a herb in slot 2 and no enemy adjacent: eat it.
  m = newMind(1, 0)
  obs = blank(5, 5, 30)
  obs[ScalarsOffset + 18 + 2] = 11
  doAssert m.decide(obs, 0) == 8 + 2, "eat the herb"
  doAssert m.heals == 1
  # 5. Healthy, same-level enemy three tiles away: hunt toward it.
  m = newMind(1, 0)
  obs = blank(5, 5, 90)
  obs.putEnemy(CenterRow - 3, CenterCol, 0, 1)
  let hunt = m.decide(obs, 0)
  doAssert hunt == 1 + 22 or hunt == 1, "move up toward prey, got " & $hunt
  doAssert m.hunts == 1
  # 6. Tool held, prof 1, tier-1 ore two tiles right: walk toward it.
  m = newMind(1, 0)
  obs = blank(1, 1, 90)
  obs.holdTool(1)
  obs.putItem(CenterRow, CenterCol + 2, 12, 1)
  let harvest = m.decide(obs, 0)
  doAssert harvest == 2, "walk right onto the ore, got " & $harvest
  doAssert m.harvests == 1
  # 7. Prof 8 with a tier-1 tool: a tier-1 resource no longer levels; with
  # gold, the engine goes shopping instead.
  m = newMind(1, 0)
  obs = blank(9, 8, 90)
  obs.holdTool(1)
  obs[ScalarsOffset + 11] = 20
  doAssert m.decide(obs, 0) == 20, "press BUY"
  obs[ScalarsOffset + 8] = 1                     # buy-tier mode
  doAssert m.decide(obs, 1) == 9, "pick tier 2"
  obs[ScalarsOffset + 8] = 2                     # buy-item mode
  let bought = m.decide(obs, 2)
  doAssert bought == 8, "buy a helm (item type 1), got " & $bought
  doAssert m.buys == 1
  # 8. Full inventory of junk gems: sell one.
  m = newMind(1, 0)
  obs = blank(5, 5, 90)
  for slot in 0 ..< 12:
    obs[ScalarsOffset + 18 + slot] = 7          # earth gems
  doAssert m.decide(obs, 0) == 21, "press SELL"
  obs[ScalarsOffset + 8] = 3
  doAssert m.decide(obs, 1) == 8, "select slot 0"
  obs[ScalarsOffset + 8] = 4
  doAssert m.decide(obs, 2) == 16, "price key 9"
  doAssert m.sells == 1
  # 9. Nothing around: wander with a move action, and keep the direction.
  m = newMind(1, 0)
  obs = blank(5, 5, 90)
  let first = m.decide(obs, 0)
  doAssert first != 4, "wander, not noop"
  let second = m.decide(obs, 1)
  doAssert (second mod 22) == (first mod 22), "persistent direction"
  echo "scripted_test: OK"

main()

