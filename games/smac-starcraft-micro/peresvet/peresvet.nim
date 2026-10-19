## Peresvet — Smac Starcraft Micro policy for Andre von Auto.
## The seat is deliberately thin: it connects to the Sprite v1 player
## socket, sends ONE chat frame (0x81) carrying its registration, and
## thereafter only answers every binary frame with Ready (0x85). The
## game container compiles every directive; a seat sends no inputs
## (docs/protocol_player.md).
##
## Default is the published `focusfire` baseline, not the LLM prompt.
## The server sets isLlm := prompt.len > 0, so a non-empty prompt makes
## five simultaneous LLM seats that split the kill order. focusfire
## derives the SAME target from public state (threatened, then lowest
## hp); a victory is 0.60 of the battle score. PLAYER_SCRIPTED=""
## restores the LLM seat; "charge" is the weaker filler.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (LLM seats only)
##   PLAYER_SCRIPTED "focusfire" (default) | "charge" | "" (LLM)
## Upload note: the focusfire default needs no Bedrock. LLM override
## still needs --secret-env USE_BEDROCK=true or the seat silently plays
## scripted.

import std/[json, options, os, strutils], whisky

const defaultPrompt = """
You are Peresvet, the warrior monk, commanding ONE unit in a five-cog squad.
Reply with one JSON object: a short note, and exactly one cogs entry for your
own unit with intent, target_id, target, and say. Every turn, even when the
target is unchanged, name a target_id and put the same id in say (e.g. "E3")
so five simultaneous decisions become one volley.
Pick the kill target by this rule: among living enemies, prefer any within
420 px of a friendly unit; then lowest hp; break ties by distance to our
rangers. If squadmates' say or notes named a living target last turn, join it
instead of starting a new one - check focused_by to see the volley forming.
If you are a RANGER: if any melee enemy is within 200 px of you, intent kite
with that enemy as target_id; otherwise intent focus on the kill target. Never
walk closer than you must; your 380 px range is the squad's whole damage.
If you are a BLADE: if a ranger is alive and a melee enemy is within 260 px of
it, intent screen; otherwise intent focus on the kill target - but when the
enemy army outnumbers us, focus the living enemy nearest yourself instead of
stacking arcs on one dying body.
When theirs.alive is 1, everyone focuses it: a win is 0.60, the biggest term.
When the battle is lost (you are the last alive against several), do NOT
suicide: kite away forever - banked damage and survival still score, a wipe
ends the battle. Keep note under 160 runes, say under 10.
"""

proc chatBlob(text: string): string =
  ## Sprite v1 client chat packet: 0x81, u16 little-endian length, bytes.
  result = newString(text.len + 3)
  result[0] = char(0x81)
  result[1] = char(text.len and 0xff)
  result[2] = char((text.len shr 8) and 0xff)
  for i, ch in text:
    result[i + 3] = ch

const readyBlob = "\x85"

proc main() =
  let
    promptEnv = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "focusfire").strip()
    ## Server isLlm := prompt.len > 0; a non-empty prompt would ignore
    ## the scripted baseline and run five independent LLM seats.
    prompt = if scripted.len > 0: "" else: promptEnv
    url = getEnv("COWORLD_PLAYER_WS_URL")
  if url == "":
    quit("peresvet: COWORLD_PLAYER_WS_URL is not set", 1)
  echo "peresvet: connecting to ", url, " kind=",
    (if scripted.len > 0: "scripted " & scripted else: "llm")
  let ws = newWebSocket(url)
  var registrationNode = %*{
    "type": "register",
    "prompt": prompt,
    "policy": "Peresvet"
  }
  if scripted.len > 0:
    registrationNode["scripted"] = %scripted
  else:
    registrationNode["scripted"] = newJNull()
  let registration = $registrationNode
  # Joins are slot-sequential: re-send the registration over the first
  # ~10 s of frames so a held slot still picks it up when it lands.
  ws.send(chatBlob(registration), BinaryMessage)
  var frames = 0
  while true:
    var received: Option[Message]
    try:
      received = ws.receiveMessage()
    except CatchableError:
      # A close frame raises; the episode is over. Exit 0 or the seat
      # fails certification intermittently (docs/protocol_player.md).
      echo "peresvet: websocket closed (", getCurrentExceptionMsg(), ")"
      break
    if received.isNone:
      continue
    let message = received.get()
    if message.kind == Ping:
      ws.send(message.data, Pong)
      continue
    if message.kind != BinaryMessage:
      continue
    inc frames
    if frames <= 240:
      ws.send(chatBlob(registration), BinaryMessage)
    ws.send(readyBlob, BinaryMessage)
  quit(0)

main()
