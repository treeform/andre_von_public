## Nochnitsa — Nightshift policy for Andre von Auto.
## Command player: a Nim rewrite of the `clockwork` scripted baseline
## (deterministic legal moves, honest claims — Villager when dealt
## Werewolf/Minion — bids to speak once, never kill-votes a known fellow
## werewolf). The Python source repo is private, so this is a faithful
## reconstruction from docs/protocol_player.md.
##
## Liveness is the whole game for a scripted seat: a scene only scores
## if we answer every mandatory window (night action, every who-speaks
## ballot, the kill vote, and speech when elected). So we answer every
## prompt immediately and deterministically; strategize / post-night /
## debrief windows are scoring-exempt and are skipped entirely.
##
## Kill vote: the docs' common-knowledge circle vote ((seat+1) mod N —
## the canonical "kill no one") — skipping self and any known fellow
## werewolf.
## Zero model calls — no secret-envs needed at upload time.

import std/[algorithm, json, os, sets, strutils], coworld_client

type Nochnitsa = ref object
  seat: int
  seatsTotal: int
  scene: int
  dealtRole: string
  knownWolves: HashSet[int]
  speechCap: int
  hasBid: bool
  nightNotes: seq[string]

proc pickOther(policy: Nochnitsa, salt: int): int =
  ## Deterministic other-seat pick, varied by scene so repeated scenes
  ## are not identical.
  result = (policy.seat + 1 + (policy.scene + salt) mod
    max(policy.seatsTotal - 1, 1)) mod policy.seatsTotal
  if result == policy.seat:
    result = (result + 1) mod policy.seatsTotal

proc rolePlan(policy: Nochnitsa, role: string): JsonNode =
  ## The preregistered night plan for a role, per the reply schemas in
  ## docs/protocol_player.md. Plans are applied only when the role acts,
  ## so a werewolf can preregister the lone-wolf center peek.
  case role
  of "doppelganger":
    %*{"target": policy.pickOther(0)}
  of "seer":
    %*{"mode": "player", "target": policy.pickOther(1)}
  of "robber":
    %*{"target": policy.pickOther(2)}
  of "troublemaker":
    let a = (policy.seat + 1) mod policy.seatsTotal
    let b = (policy.seat + 2) mod policy.seatsTotal
    %*{"targets": [a, b]}
  of "drunk", "werewolf":
    %*{"center": 1 + policy.scene mod 3}
  else:
    # Minion, masons, insomniac, hunter, tanner, villager: nothing to
    # plan; decline explicitly rather than time out.
    %*{"mode": "decline"}

proc sortedKeys(node: JsonNode): seq[string] =
  for key, _ in node:
    result.add key
  result.sort()

proc nightReply(policy: Nochnitsa, request: JsonNode): JsonNode =
  var role = policy.dealtRole.toLowerAscii()
  if request{"stage"}.getStr() == "copied_role":
    role = request{"acting_as"}.getStr(role).toLowerAscii()
  result = policy.rolePlan(role)
  # If the request enumerates legal actions as complete objects and our
  # plan's shape is not among them, defer to the first legal action.
  let legal = request{"legal_actions"}
  if legal != nil and legal.kind == JArray and legal.len > 0 and
      legal[0].kind == JObject:
    var matched = false
    for option in legal:
      if option.kind == JObject and option.sortedKeys() == result.sortedKeys():
        matched = true
        break
    if not matched:
      result = legal[0].copy()
  result["request_id"] = request{"request_id"}

proc noteNight(policy: Nochnitsa, message: JsonNode) =
  ## Record observations; best-effort extraction of fellow-werewolf seats
  ## so the kill vote never lands on a partner.
  for observation in message{"observations"}.getElems():
    policy.nightNotes.add $observation
    if "werewol" notin ($observation).toLowerAscii():
      continue
    for key in ["seats", "werewolves", "partners"]:
      let field = observation{key}
      if field != nil and field.kind == JArray:
        for entry in field:
          if entry.kind == JInt and entry.getInt() != policy.seat:
            policy.knownWolves.incl entry.getInt()
    let single = observation{"seat"}
    if single != nil and single.kind == JInt and
        single.getInt() != policy.seat:
      policy.knownWolves.incl single.getInt()

proc speechText(policy: Nochnitsa): string =
  ## Honest claim (Villager when dealt Werewolf or Minion), plus the
  ## circle-vote convention as the default day plan.
  let dealt = policy.dealtRole.toLowerAscii()
  let claim = if dealt in ["werewolf", "minion"]: "villager" else: dealt
  result = "Seat " & $policy.seat & " here. I was dealt " & claim & "."
  if claim notin ["werewolf", "minion", "villager"] and
      policy.nightNotes.len > 0:
    result.add " My night record: " & policy.nightNotes.join("; ") & "."
  result.add " Unless someone has hard information, I back the circle " &
    "vote: everyone votes seat plus one mod " & $policy.seatsTotal &
    ", and nobody dies."
  if result.len > policy.speechCap:
    result = result[0 ..< policy.speechCap]

proc killTarget(policy: Nochnitsa): int =
  result = (policy.seat + 1) mod policy.seatsTotal
  var guard = 0
  while (result == policy.seat or result in policy.knownWolves) and
      guard < policy.seatsTotal:
    result = (result + 1) mod policy.seatsTotal
    inc guard

proc handle(policy: Nochnitsa, client: CoworldClient, message: JsonNode) =
  case message{"type"}.getStr()
  of "scene_start":
    policy.scene = message{"session", "scene"}.getInt()
    policy.seatsTotal = max(message{"session", "seats"}.getElems().len, 3)
    policy.seat = message{"you", "seat"}.getInt(policy.seat)
    policy.dealtRole = message{"you", "dealt_role"}.getStr()
    policy.speechCap = message{"session", "limits", "speech_chars"}.getInt(1200)
    policy.knownWolves.clear()
    policy.hasBid = false
    policy.nightNotes = @[]
    echo "nochnitsa: scene ", policy.scene, " seat ", policy.seat,
      " dealt ", policy.dealtRole
  of "night_preregister_request":
    client.send(policy.nightReply(message))
  of "night_result":
    # Also opens the post-night window; it is liveness-exempt, so we
    # only record observations.
    policy.noteNight(message)
  of "who_speaks_request":
    var reply = %*{"points": 0, "request_id": message{"request_id"}}
    if not policy.hasBid and message{"cycle"}.getInt(1) == 1:
      policy.hasBid = true
      reply["points"] = %1
      reply["nominee"] = %policy.seat
    client.send(reply)
  of "speech_start":
    if message{"speaker"}.getInt(-1) == policy.seat:
      client.send(%*{"type": "output_frame", "ch": "speech",
        "text": policy.speechText(), "request_id": message{"request_id"}})
      client.send(%*{"type": "output_done",
        "request_id": message{"request_id"}})
  of "kill_vote_request":
    client.send(%*{"target": policy.killTarget(),
      "request_id": message{"request_id"}})
  of "snapshot":
    # Reconnect: rebuild scene state, then answer whatever is pending.
    let sceneStart = message{"scene_start"}
    if sceneStart != nil and sceneStart.kind == JObject:
      var replayed = sceneStart.copy()
      replayed["type"] = %"scene_start"
      policy.handle(client, replayed)
    for observation in message{"night_observations"}.getElems():
      policy.nightNotes.add $observation
    for prompt in message{"outstanding_prompts"}.getElems():
      policy.handle(client, prompt)
  of "scene_reveal", "notebook_ack", "lobby", "who_speaks_reveal",
     "speech_delta", "speech_end", "night_preregister_result":
    # Reveals and the debrief window are liveness-exempt; nothing to send.
    discard
  of "final":
    echo "nochnitsa: final ", message{"scores"}
    quit(0)
  else:
    discard

proc main() =
  # The player endpoint pins a protocol version in the query string
  # (docs/protocol_player.md); append it if the platform URL lacks one.
  let url = getEnv("COWORLD_PLAYER_WS_URL")
  if url != "" and "protocol_version=" notin url:
    let separator = if "?" in url: "&" else: "?"
    putEnv("COWORLD_PLAYER_WS_URL", url & separator & "protocol_version=0.4.0")
  let client = newCoworldClient("nochnitsa")
  let policy = Nochnitsa(seat: 0, seatsTotal: 3, speechCap: 1200)
  client.run proc(message: JsonNode) =
    policy.handle(client, message)

main()
