## Deterministic action selection for the measured position opening book.

import std/[math, strutils]
import observation, openings

proc isNeutral(action: Action): bool =
  ## Report whether an action expands into unclaimed territory.
  getBool(action.meta, "expansion") or action.id.startsWith("expand:")

proc actionPercent(action: Action): int =
  ## Read one legal action's troop commitment percentage.
  let explicit = getInt(action.meta, "troopPercent", -1)
  if explicit >= 0:
    return explicit
  (getFloat(action.meta, "troopPercentage", -0.01) * 100.0).round().int

proc tileX(tile, mapWidth: int): int =
  ## Decode a map tile's horizontal coordinate.
  tile mod mapWidth

proc tileY(tile, mapWidth: int): int =
  ## Decode a map tile's vertical coordinate.
  tile div mapWidth

proc directionScore(action: Action, mode: BoatMode, mapWidth: int): int =
  ## Score one neutral boat option under a position-specific direction rule.
  let
    source = getInt(action.meta, "sourceTile")
    target = getInt(action.meta, "targetTile")
    distance = abs(tileX(target, mapWidth) - tileX(source, mapWidth)) +
      abs(tileY(target, mapWidth) - tileY(source, mapWidth))
  case mode
  of boatFirst: 0
  of boatNorth: -tileY(target, mapWidth)
  of boatSouth: tileY(target, mapWidth)
  of boatEast: tileX(target, mapWidth)
  of boatWest: -tileX(target, mapWidth)
  of boatNear: -distance
  of boatFar: distance

proc closestNeutral(actions: seq[Action], kind: string, percent: int,
    mode = boatFirst, mapWidth = 1000): string =
  ## Select the closest commitment and best direction deterministically.
  var
    bestDistance = high(int)
    bestDirection = low(int)
  for action in actions:
    if action.kind != kind or not isNeutral(action):
      continue
    let
      candidateDistance = abs(actionPercent(action) - percent)
      candidateDirection = directionScore(action, mode, mapWidth)
    if candidateDistance < bestDistance or
        (candidateDistance == bestDistance and
          candidateDirection > bestDirection):
      result = action.id
      bestDistance = candidateDistance
      bestDirection = candidateDirection

proc playerContact(world: Observation): bool =
  ## Report whether another living player has reached our land border.
  for rival in world.rivals:
    if rival.isAlive and rival.sharesBorder:
      return true

proc openingAction*(world: Observation, actions: seq[Action],
    landStalled: bool): string =
  ## Select a measured opening action until contact or its empirical cutoff.
  let opening = openingFor(world.spawnTile)
  if opening.spawnTile < 0 or not opening.enabled or
      not world.hasSpawned or
      world.turnNumber > opening.stopTurn or world.incomingAttacks > 0 or
      world.homeDanger == "high" or playerContact(world):
    return ""
  let
    decision = max(0, (world.turnNumber - 400) div 100)
    step = opening.steps[min(decision, OpeningStepCount - 1)]
  case step.kind
  of openingLand:
    if not landStalled:
      result = closestNeutral(actions, "attack", step.percent)
    if result.len == 0:
      result = closestNeutral(
        actions,
        "boat",
        step.percent,
        step.boatMode,
        opening.mapWidth
      )
  of openingBoat:
    result = closestNeutral(
      actions,
      "boat",
      step.percent,
      step.boatMode,
      opening.mapWidth
    )
  of openingHold:
    for action in actions:
      if action.kind == "hold":
        return action.id
