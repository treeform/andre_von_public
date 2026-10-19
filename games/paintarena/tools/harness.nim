## Offline sweep harness for iskusnitsa.
## Feeds synthetic Paintarena observations through sweepMove and checks
## boustrophedon order: no off-by-one at row ends, odd slots mirror.
##
##   nim c --hints:off -r games/paintarena/tools/harness.nim

import std/json
import ../iskusnitsa/iskusnitsa

const
  Width = 12
  Height = 8
  MaxTicks = 100

proc observation(slot, x, y, width, height: int): JsonNode =
  result = %*{
    "type": "observation",
    "slot": slot,
    "width": width,
    "height": height,
    "positions": [[0, 0], [width - 1, height - 1]],
    "tile_owners": [-1, -1, -1, -1],
    "scores": [0, 0],
    "tick": 0,
    "max_ticks": MaxTicks,
    "paused": false,
    "tick_rate": 5.0,
    "done": false
  }
  result["positions"].elems[slot] = %*[x, y]

proc applyMove(dir: string; x, y, width, height: int): (int, int) =
  var nx = x
  var ny = y
  case dir
  of "right": inc nx
  of "left": dec nx
  of "down": inc ny
  of "up": dec ny
  else: discard
  (max(0, min(width - 1, nx)), max(0, min(height - 1, ny)))

proc simulate(slot, startX, startY, width, height, ticks: int): tuple[
    unique: int, stuckAt: int, path: seq[string]] =
  var
    x = startX
    y = startY
    seen = newSeq[bool](width * height)
  seen[y * width + x] = true
  result.unique = 1
  result.stuckAt = -1
  for t in 0 ..< ticks:
    let dir = sweepMove(observation(slot, x, y, width, height), slot)
    result.path.add(dir)
    let (nx, ny) = applyMove(dir, x, y, width, height)
    if nx == x and ny == y:
      result.stuckAt = t
      break
    x = nx
    y = ny
    let i = y * width + x
    if not seen[i]:
      seen[i] = true
      inc result.unique

when isMainModule:
  echo "=== spawn / row-end / odd-slot mirror ==="
  doAssert sweepMove(observation(0, 0, 0, Width, Height), 0) == "right"
  doAssert sweepMove(observation(0, 10, 0, Width, Height), 0) == "right"
  doAssert sweepMove(observation(0, 11, 0, Width, Height), 0) == "down",
    "even slot must turn down at the even-row end, not walk off"
  doAssert sweepMove(observation(0, 0, 1, Width, Height), 0) == "down",
    "even slot must turn down at the odd-row end (x=0)"
  doAssert sweepMove(observation(0, 1, 1, Width, Height), 0) == "left"
  doAssert sweepMove(observation(0, 11, 6, Width, Height), 0) == "down"
  doAssert sweepMove(observation(0, 0, 7, Width, Height), 0) == "up"

  doAssert sweepMove(observation(1, 11, 7, Width, Height), 1) == "up",
    "odd slot spawn (bottom-right, odd y) mirrors by going up"
  doAssert sweepMove(observation(1, 11, 6, Width, Height), 1) == "left"
  doAssert sweepMove(observation(1, 0, 6, Width, Height), 1) == "up",
    "odd slot must turn up at the even-row end, not walk off"
  doAssert sweepMove(observation(1, 0, 5, Width, Height), 1) == "right"
  doAssert sweepMove(observation(1, 11, 5, Width, Height), 1) == "up",
    "odd slot must turn up at the odd-row end (x=width-1)"

  echo "  spawn/row-end assertions ok"

  echo "=== spec-shaped JSON (ints, tick_rate float) ==="
  let spec = parseJson("""
  {
    "type": "observation",
    "slot": 0,
    "width": 12,
    "height": 8,
    "positions": [[0, 0], [11, 7]],
    "tile_owners": [0, -1, -1, 1],
    "scores": [0, 0],
    "tick": 0,
    "max_ticks": 100,
    "paused": false,
    "tick_rate": 5.0,
    "done": false
  }
  """)
  doAssert sweepMove(spec, 0) == "right"
  doAssert sweepMove(spec, 1) == "up"
  echo "  spec observation ok"

  echo "=== float coordinates (getInt-on-JFloat landmine) ==="
  let floats = parseJson("""
  {
    "type": "observation",
    "slot": 0,
    "width": 12.0,
    "height": 8.0,
    "positions": [[0.0, 0.0], [11.0, 7.0]]
  }
  """)
  doAssert sweepMove(floats, 0) == "right",
    "float width/x must not collapse to 0 and emit up/stay"
  doAssert sweepMove(floats, 1) == "up"
  echo "  float observation ok"

  echo "=== {x,y} position objects ==="
  let objects = parseJson("""
  {
    "slot": 0,
    "width": 12,
    "height": 8,
    "positions": [{"x": 11, "y": 0}, {"x": 11, "y": 7}]
  }
  """)
  doAssert sweepMove(objects, 0) == "down"
  doAssert sweepMove(objects, 1) == "up"
  echo "  object positions ok"

  echo "=== 12x8 x 100-tick coverage ==="
  let even = simulate(0, 0, 0, Width, Height, MaxTicks)
  echo "  even slot unique=", even.unique, "/", Width * Height,
    " stuckAt=", even.stuckAt, " first=", even.path[0],
    " turn=", even.path[11]
  doAssert even.stuckAt < 0
  doAssert even.path[10] == "right" and even.path[11] == "down"
  doAssert even.unique == Width * Height

  let odd = simulate(1, Width - 1, Height - 1, Width, Height, MaxTicks)
  echo "  odd slot unique=", odd.unique, "/", Width * Height,
    " stuckAt=", odd.stuckAt, " first=", odd.path[0],
    " turn=", odd.path[12]
  doAssert odd.stuckAt < 0
  doAssert odd.path[0] == "up"
  doAssert odd.path[11] == "left" and odd.path[12] == "up"
  # Reference _sweep_move uses y%2, so on even-height boards the odd slot
  # leaves the spawn row immediately (11 tiles of y=height-1 stay unvisited
  # on the first pass). 96 - 11 = 85.
  doAssert odd.unique == Width * Height - (Width - 1)

  echo "harness ok"
