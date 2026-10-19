## Marya Iskusnitsa — Paintarena policy for Andre von Auto.
## Command player: a Nim rewrite of the sweep-painter example
## (coworld.examples.paintarena.player.player in the metta repo). Each
## observation carries the full grid state; we reply with one move that
## boustrophedon-sweeps the arena, repainting every tile in rows. Slot
## parity mirrors the sweep so the two default players cover the board
## from opposite corners.
##
## Protocol (game/docs/player_protocol_spec.md): the server sends
## {"type": "observation", slot, width, height, positions, tile_owners,
## scores, tick, ...} every tick; the player replies {"move": <dir>}
## with dir in up | down | left | right | stay. Invalid moves become
## stay. A {"type": "final"} message ends the episode.

import std/json, coworld_client

proc jsonInt(node: JsonNode): int =
  ## JSON numbers may arrive as JInt or JFloat. std/json.getInt returns 0
  ## on JFloat, which would pin the sweep at the origin.
  if node.isNil:
    return 0
  case node.kind
  of JInt:
    node.getInt()
  of JFloat:
    int(node.getFloat())
  else:
    0

proc readXY(position: JsonNode): (int, int) =
  if position.isNil:
    return (0, 0)
  if position.kind == JArray and position.len >= 2:
    return (jsonInt(position[0]), jsonInt(position[1]))
  if position.kind == JObject:
    return (jsonInt(position{"x"}), jsonInt(position{"y"}))
  (0, 0)

proc sweepMove*(message: JsonNode, slot: int): string =
  ## Port of the reference _sweep_move: even slots serpentine
  ## right-then-left descending, odd slots left-then-right ascending.
  let
    positions = message{"positions"}
    position =
      if positions.isNil or positions.kind != JArray or slot < 0 or
          slot >= positions.len: nil
      else: positions[slot]
    (x, y) = readXY(position)
    width = jsonInt(message{"width"})
    height = jsonInt(message{"height"})
  if slot mod 2 == 0:
    if y mod 2 == 0 and x < width - 1:
      return "right"
    if y mod 2 == 1 and x > 0:
      return "left"
    if y < height - 1:
      return "down"
    return "up"
  if y mod 2 == 0 and x > 0:
    return "left"
  if y mod 2 == 1 and x < width - 1:
    return "right"
  if y > 0:
    return "up"
  "down"

proc main() =
  let client = newCoworldClient("iskusnitsa")
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "observation":
      try:
        let slot = jsonInt(message{"slot"})
        client.send(%*{"move": sweepMove(message, slot)})
      except CatchableError as err:
        echo "iskusnitsa: bad observation: ", err.msg
        client.send(%*{"move": "stay"})
    of "final":
      echo "iskusnitsa: final"
      quit(0)
    else:
      discard

when isMainModule:
  main()
