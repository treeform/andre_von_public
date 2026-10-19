## Early-life guard on top of the MMONet: a scripted override that fires
## only while the agent is fragile (combat level <= FragileLevel) and a
## live, clearly stronger enemy is about to reach it. Everything else is
## the network's decision. The observation trust model is the one from
## the buyan:v1 scripted bot (git 748cf54): entity bytes 4-9 of the
## legacy window are stale-prone, so a per-cell liveness map, shifted by
## our own confirmed movement, decides which enemy imprints are real.
##
## Ground truth for every constant is sims/nmmo/vendor/upstream/nmmo3.h.

## Obs layout (compute_all_obs, nmmo3.h:926-1020)

const
  windowRows = 11
  windowCols = 15
  tileBytes = 10
  centerRow = 5
  centerCol = 7
  scalarsOffset = windowRows * windowCols * tileBytes   # 1650
  observationSize* = scalarsOffset + 47 + 10             # 1707

const
  terrainByte = 1        ## 0 grass, 1 dirt, 2 stone, 3 water
  entityTypeByte = 4     ## stale-prone from here down
  entityDeltaByte = 6    ## clamp((seen comb - my comb) / 2, 0, 4)
  entityAnimByte = 8

const
  scalarCombatLevel = 1
  scalarAnim = 4
  scalarUiMode = 8
  scalarInCombat = 12

const
  grassTerrain = 0
  dirtTerrain = 1
  enemyEntity = 2
  deathAnim = 5
  moveAnim = 1
  runAnim = 6
  playMode = 0

## Actions (nmmo3.h:46-70)

const
  downAction = 0
  upAction = 1
  rightAction = 2
  leftAction = 3
  runOffset = 22
  moveActions = [downAction, upAction, rightAction, leftAction]

## Guard thresholds

const
  FragileLevel* = 3      ## guard only while combat level <= this
  DangerDistance = 2     ## stronger live enemy within this chebyshev ring
  liveTtl = 3            ## ticks a changed entity cell stays trusted

type
  Guard* = object
    prevTiles: seq[uint8]
    live: seq[int8]
    hasPrev: bool
    lastAction: int
    overrides*: int

proc moveDelta(action: int): (int, int) =
  case action
  of downAction: (1, 0)
  of upAction: (-1, 0)
  of rightAction: (0, 1)
  else: (0, -1)

proc isWalk(action: int): bool =
  action >= downAction and action <= leftAction

proc isRun(action: int): bool =
  action - runOffset >= downAction and action - runOffset <= leftAction

proc tileByte(obs: openArray[uint8], r, c, b: int): int =
  int(obs[(r * windowCols + c) * tileBytes + b])

proc scalar(obs: openArray[uint8], i: int): int =
  int(obs[scalarsOffset + i])

proc passable(obs: openArray[uint8], r, c: int): bool =
  if r < 0 or r >= windowRows or c < 0 or c >= windowCols:
    return false
  obs.tileByte(r, c, terrainByte) in [grassTerrain, dirtTerrain]

proc newGuard*(): Guard =
  Guard(prevTiles: newSeq[uint8](scalarsOffset),
        live: newSeq[int8](windowRows * windowCols), lastAction: 4)

proc reset*(guard: var Guard) =
  ## New life: forget the window.
  guard.hasPrev = false
  guard.lastAction = 4

proc ownShift(guard: Guard, obs: openArray[uint8]): (int, int) =
  ## Window slide since last tick: the fresh anim scalar proves whether
  ## the last move or run landed, the remembered action gives direction.
  var walk = guard.lastAction
  if isRun(walk):
    walk -= runOffset
  if not isWalk(walk):
    return (0, 0)
  let (dr, dc) = moveDelta(walk)
  let anim = obs.scalar(scalarAnim)
  if anim == moveAnim:
    (dr, dc)
  elif anim == runAnim:
    (2 * dr, 2 * dc)
  else:
    (0, 0)

proc updateLiveness(guard: var Guard, obs: openArray[uint8]) =
  ## Decay-and-shift the trust map by our own movement, then re-arm every
  ## cell whose entity bytes changed at the same window offset.
  if not guard.hasPrev:
    for i in 0 ..< guard.live.len:
      guard.live[i] = 0
    for i in 0 ..< scalarsOffset:
      guard.prevTiles[i] = obs[i]
    guard.hasPrev = true
    return
  let (dr, dc) = guard.ownShift(obs)
  var shifted = newSeq[int8](windowRows * windowCols)
  for r in 0 ..< windowRows:
    for c in 0 ..< windowCols:
      let sr = r + dr
      let sc = c + dc
      if sr >= 0 and sr < windowRows and sc >= 0 and sc < windowCols:
        shifted[r * windowCols + c] = guard.live[sr * windowCols + sc]
  for r in 0 ..< windowRows:
    for c in 0 ..< windowCols:
      let base = (r * windowCols + c) * tileBytes
      var changed = false
      for b in entityTypeByte ..< tileBytes:
        if obs[base + b] != guard.prevTiles[base + b]:
          changed = true
          break
      guard.live[r * windowCols + c] =
        if changed: int8(liveTtl)
        else: max(shifted[r * windowCols + c] - 1, 0).int8
  for i in 0 ..< scalarsOffset:
    guard.prevTiles[i] = obs[i]

proc threats(guard: Guard, obs: openArray[uint8]): seq[(int, int)] =
  ## Live cells hinting an enemy at least two combat levels above us
  ## within the danger ring. While in_combat says something is hitting
  ## us, adjacent imprints are trusted even if static.
  let inCombat = obs.scalar(scalarInCombat) > 0
  for r in 0 ..< windowRows:
    for c in 0 ..< windowCols:
      if obs.tileByte(r, c, entityTypeByte) != enemyEntity:
        continue
      if obs.tileByte(r, c, entityAnimByte) == deathAnim:
        continue
      if obs.tileByte(r, c, entityDeltaByte) < 1:
        continue
      let distance = max(abs(r - centerRow), abs(c - centerCol))
      if distance > DangerDistance:
        continue
      if guard.live[r * windowCols + c] <= 0 and
          not (inCombat and distance <= 1):
        continue
      result.add((r, c))

proc threatDistance(r, c: int, cells: seq[(int, int)]): int =
  result = high(int)
  for (tr, tc) in cells:
    result = min(result, max(abs(r - tr), abs(c - tc)))

proc fleeAction(obs: openArray[uint8], cells: seq[(int, int)]): int =
  ## Passable move that most increases the distance to the nearest
  ## threat, upgraded to a run when both tiles are clear; -1 when no
  ## move helps.
  let here = threatDistance(centerRow, centerCol, cells)
  var best = -1
  var bestDistance = here
  for action in moveActions:
    let (dr, dc) = moveDelta(action)
    if not obs.passable(centerRow + dr, centerCol + dc):
      continue
    var distance = threatDistance(centerRow + dr, centerCol + dc, cells)
    var candidate = action
    if obs.passable(centerRow + 2 * dr, centerCol + 2 * dc):
      let runDistance = threatDistance(centerRow + 2 * dr,
                                       centerCol + 2 * dc, cells)
      if runDistance > distance:
        distance = runDistance
        candidate = action + runOffset
    if distance > bestDistance:
      bestDistance = distance
      best = candidate
  best

proc decide*(guard: var Guard, obs: openArray[uint8],
             networkAction: int): int =
  ## Returns the action to play: the network's unless the guard fires.
  guard.updateLiveness(obs)
  result = networkAction
  if obs.scalar(scalarCombatLevel) <= FragileLevel and
      obs.scalar(scalarUiMode) == playMode:
    let cells = guard.threats(obs)
    if cells.len > 0:
      let flee = fleeAction(obs, cells)
      if flee >= 0 and flee != networkAction:
        result = flee
        inc guard.overrides
  guard.lastAction = result
