## Zodchiy — Minecraft policy for Andre von Auto.
## The minecraft player container is deliberately thin: it connects,
## sends one Sprite v1 chat packet carrying its registration (operator
## prompt or scripted baseline), and thereafter only acknowledges
## frames; every primitive is computed inside the GAME container, the
## only one the platform injects the anthropic_api_key secret into
## (docs/protocol_player.md -> cogame-minecraft/docs/PROTOCOL.md). The
## wire is the Sprite v1 BINARY protocol: register is 0x81 + u16
## little-endian length + payload, re-sent over the first ~10 s because
## the lobby can hold an unappliable registration, and a Ready byte
## (0x85) after each received frame paces fastMode — this seat sends no
## inputs, so readiness pacing is legitimate here.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED play a scripted baseline instead (miner | scrounger)

import std/[json, monotimes, options, os, times], whisky

const defaultPrompt = """
You are Zodchiy, the master builder. One rung deeper on the ladder beats
every rung below it combined — depth first, speed second, nothing else.
The ladder: log > planks > crafting table > wooden pickaxe > cobblestone
> stone pickaxe > iron ore > furnace > iron ingot > iron pickaxe >
diamond. milestones.next tells you the rung to chase; chase it.
Budget: 48 turns of 20 ticks. A turn costs 20 ticks even if you send one
action, so ALWAYS fill the turn with up to 12 actions chained end to end.
Surface (2-3 turns, no more): goto the nearest tree, mine it (3 logs),
chop a second tree (6 logs total — tables cost 4 planks each and you
will want a table on a lower level too). craft_planks n=6, craft_sticks
n=2 (8 sticks covers all three pickaxes), place_crafting_table,
craft_wooden_pickaxe. Then dig_down where you stand. Never wander.
Stone level z1: tunnel east or toward known stone, collect 12+
cobblestone (3 stone pickaxe + 8 furnace + 1 spare bridge block) and 3+
coal for smelting. place_crafting_table by your shaft if none is within
reach, craft_stone_pickaxe, then dig_down again. Grab coal ore whenever
it is one tunnel-step off your line; skip anything two levels of detours
away.
Iron depth z2: branch-mine straight corridors three rows apart with
tunnel; the 5x5 window sweeps everything that lattice passes. Mine 3
raw_iron (iron pickaxe needs 3 ingots), place_furnace, smelt_iron n=3,
place a table if needed, craft_iron_pickaxe. If nearest shows iron_ore,
goto it; goto ends facing the block, then mine.
Diamond depth z3: same lattice. The moment view or nearest shows D, goto
and mine it — the diamond ends the run in triumph.
Lava law: never move onto a visible ! — stepping in is instant death.
dig_down onto unseen lava is SAFE (the floor breaks, you stay put), so
blind descent is always allowed. When lava appears next to you the turn
ends — re-plan around it, or place_block (1 cobblestone) to fill the one
cell in your way. Keep one route note back to your shaft; you climb up
only where you dug down.
Craft discipline: craft the moment ingredients are complete — a rung
unlit is worth double everything below it, and speedBonus pays for
early. Crafting an owned pickaxe is a free no-op, never resend it.
Recipes: planks 1 log>4; sticks 2 planks>4; any pickaxe 3 (planks|
cobble|ingots) + 2 sticks at a table; furnace 8 cobblestone; smelt 1 raw
iron + 1 coal at the furnace. Tools never break.
Mechanics: goto only walks ground ALREADY SEEN on this level and never
descends — after a fresh dig_down there is nothing to goto, so tunnel to
explore. A blocked move only turns you; mine acts on the faced cell.
Watch last_plan: an unreachable goto or blocked mine means your map idea
was wrong — fix it, do not resend it.
notes each turn: table/furnace/shaft coordinates per level, lava cells,
ore sightings, and the current plan (e.g. "z2: shaft(12,19) furnace
(13,20) need 1 iron"). say one short line of intent. Never waste a tick:
if truly idle, tunnel toward unexplored fog on the deepest level you can
mine.
"""

const
  SpriteClientChat = 0x81'u8
  SpriteClientReady = 0x85'u8
  RegistrationResends = 10

proc chatPacket(payload: string): string =
  ## One Sprite v1 chat packet: 0x81, u16 little-endian length, raw bytes.
  result = newStringOfCap(payload.len + 3)
  result.add(char(SpriteClientChat))
  result.add(char(payload.len and 0xff))
  result.add(char((payload.len shr 8) and 0xff))
  result.add(payload)

proc main() =
  let
    scripted = getEnv("PLAYER_SCRIPTED", "")
    prompt = if scripted == "": getEnv("PLAYER_PROMPT", defaultPrompt) else: ""
    url = getEnv("COWORLD_PLAYER_WS_URL")
  if url == "":
    quit("zodchiy: COWORLD_PLAYER_WS_URL is not set", 1)
  let register = %*{
    "type": "register",
    "prompt": prompt,
    "scripted": if scripted == "": newJNull() else: %scripted,
    "policy": "Zodchiy"}
  echo "zodchiy: connecting to ", url
  let ws = newWebSocket(url)
  # Registration is re-sent, not sent once: the lobby sends frames to a
  # socket before it has been admitted, so a single registration can land
  # while the seat has no index (docs/PROTOCOL.md). Re-sending is harmless.
  ws.send(chatPacket($register), BinaryMessage)
  let started = getMonoTime()
  var
    resends = 0
    lastSend = started
  while true:
    var received: Option[Message]
    try:
      received = ws.receiveMessage()
    except CatchableError:
      # The run is over when the server closes the socket.
      echo "zodchiy: websocket closed (", getCurrentExceptionMsg(), ")"
      break
    if received.isNone:
      continue
    let message = received.get()
    if message.kind == Ping:
      ws.send(message.data, Pong)
      continue
    let now = getMonoTime()
    if resends < RegistrationResends and
        (now - started).inSeconds < 11 and
        (now - lastSend).inMilliseconds >= 1000:
      ws.send(chatPacket($register), BinaryMessage)
      inc resends
      lastSend = now
    # Acknowledge every frame so fastMode can pace the run by readiness.
    ws.send($char(SpriteClientReady), BinaryMessage)
  quit(0)

main()
