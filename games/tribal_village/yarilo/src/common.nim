## Headless subset of the upstream tribal-village src/common.nim
## (coworld-tribal-village @ 7a5f6a21). The upstream module mixes game
## constants with desktop UI globals (boxy/windy); the mirror player only
## needs the game half, so the UI half is trimmed away. Every symbol kept
## here is byte-identical in behavior to upstream — the deterministic
## mirror depends on that.

import std/times
import vmath

proc nowSeconds*(): float64 =
  epochTime()

type
  OrientationDelta* = tuple[x, y: int]
  Orientation* = enum
    N = 0  # North (Up)
    S = 1  # South (Down)
    W = 2  # West (Left)
    E = 3  # East (Right)
    NW = 4 # Northwest (Up-Left)
    NE = 5 # Northeast (Up-Right)
    SW = 6 # Southwest (Down-Left)
    SE = 7 # Southeast (Down-Right)

const OrientationDeltas*: array[8, OrientationDelta] = [
  (x: 0, y: -1),   # N (North)
  (x: 0, y: 1),    # S (South)
  (x: -1, y: 0),   # W (West)
  (x: 1, y: 0),    # E (East)
  (x: -1, y: -1),  # NW (Northwest)
  (x: 1, y: -1),   # NE (Northeast)
  (x: -1, y: 1),   # SW (Southwest)
  (x: 1, y: 1)     # SE (Southeast)
]

const
  ActionVerbCount* = 8  # Added plant-resource action (verb 7)
  ActionArgumentCount* = 8

proc encodeAction*(verb: uint8, argument: uint8): uint8 =
  (verb.int * ActionArgumentCount + argument.int).uint8

proc decodeAction*(value: uint8): tuple[verb: uint8, argument: uint8] =
  (verb: (value.int div ActionArgumentCount).uint8,
   argument: (value.int mod ActionArgumentCount).uint8)

{.push inline.}
proc getOrientationDelta*(orient: Orientation): OrientationDelta =
  OrientationDeltas[ord(orient)]
{.pop.}

proc orientationToVec*(orientation: Orientation): IVec2 =
  case orientation
  of N: result = ivec2(0, -1)
  of S: result = ivec2(0, 1)
  of E: result = ivec2(1, 0)
  of W: result = ivec2(-1, 0)
  of NW: result = ivec2(-1, -1)
  of NE: result = ivec2(1, -1)
  of SW: result = ivec2(-1, 1)
  of SE: result = ivec2(1, 1)

proc ivec2*(x, y: int): IVec2 =
  result.x = x.int32
  result.y = y.int32
