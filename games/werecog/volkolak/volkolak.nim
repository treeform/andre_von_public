## Volkolak — Werecog (One Night Ultimate Werewolf, 5 seats) policy for
## Andre von Auto. Command player on cogweb.player.v1: the game asks for
## exactly one decision per observation (night action by dealt role, one
## `speak` per discussion round, one `vote`) and validates legality,
## re-requesting with `reason` on a rejected move.
##
## Rewrite of the deterministic `werecog-scripted` baseline, upgraded to
## actually use the seat's private night knowledge (the baseline ignores
## it): the Seer inspects a player and publicly names any wolf it caught,
## the Robber robs (gaining a known team), wolves bluff Villager and never
## vote each other, and votes follow a unique-role counterclaim (the
## strongest deterministic wolf signal on this deck) then seer-seen wolf
## before falling back to the baseline's next-seat vote. No LLM, no secrets.
##
## Protocol pinned from Metta-AI/metta packages/cogweb/games/werecog at the
## coworld-tournament commit (70a6a77f58) matching the shipped manifest
## docs; the metta HEAD has since reworked the day into free-form talk, so
## an unexpected phase falls back to the always-legal baseline reply.

import std/[json, strutils], coworld_client

const roleLabels = {
  "werewolf": "Werewolf", "seer": "Seer", "robber": "Robber",
  "troublemaker": "Troublemaker", "insomniac": "Insomniac",
  "villager": "Villager"}
const uniqueDealtRoles = ["seer", "robber", "troublemaker", "insomniac"]

proc roleLabel(role: string): string =
  for (id, label) in roleLabels:
    if id == role:
      return label
  role

type Knowledge = object
  ## Everything this seat privately learned, digested from view.you.
  seat: int
  playerCount: int
  dealtRole: string
  finalRole: string        # best knowledge of the card we hold at dawn
  fellowWolves: seq[int]
  sawWolfSeat: int         # seer: seat we SAW holding a werewolf card, or -1
  sawClearSeat: int        # seer: seat we saw holding a non-wolf card, or -1
  sawClearRole: string
  robbedSeat: int          # robber: who we robbed (they hold Robber now), or -1
  centerNote: string       # any center-card facts, rendered

proc seatName(view: JsonNode, seat: int): string =
  let names = view{"seatNames"}
  if names != nil and names.kind == JArray and seat >= 0 and
      seat < names.len:
    return names[seat].getStr()
  "seat " & $seat

proc claimsRole(text, role: string): bool =
  ## True when `text` is a first-person claim of this unique role. Tight
  ## prefixes so "I think Avery is the Seer" does not count; "I'm not the
  ## Seer" is excluded.
  let label = roleLabel(role).toLowerAscii()
  # Drop apostrophes so "I'm the Seer" → "im the seer"; other punctuation
  # becomes spaces so "I am the Seer." still matches.
  var normalized = text.toLowerAscii().replace("'", "").replace("’", "")
  for ch in {',', '.', '!', '?', ':', ';', '"', '-'}:
    normalized = normalized.replace($ch, " ")
  if ("not the " & label) in normalized or ("not a " & label) in normalized:
    return false
  for prefix in ["i am the ", "i am a ", "im the ", "im a ", "i was the ",
      "i was a ", "i was dealt ", "i was dealt the ", "my role is ",
      "my role is the ", "i got the ", "i got ", "as the "]:
    if (prefix & label) in normalized:
      return true
  false

proc counterclaimSeat(view: JsonNode, knowledge: Knowledge): int =
  ## First other seat that claims our unique dealt role. On this 8-card
  ## deck each of Seer/Robber/Troublemaker/Insomniac exists once, so a
  ## second claimer is lying — the LLM autopilot tells wolves to fake
  ## Seer/Robber, and a contradicted unique claim is the strongest
  ## deterministic wolf signal. -1 if none.
  result = -1
  if knowledge.dealtRole notin uniqueDealtRoles:
    return
  let discussion = view{"discussion"}
  if discussion == nil or discussion.kind != JArray:
    return
  for utterance in discussion:
    if utterance.kind != JObject:
      continue
    let speaker = utterance{"seat"}.getInt(-1)
    if speaker < 0 or speaker == knowledge.seat:
      continue
    if claimsRole(utterance{"text"}.getStr(), knowledge.dealtRole):
      return speaker

proc digest(view: JsonNode, seat: int): Knowledge =
  result.seat = seat
  result.playerCount = view{"playerCount"}.getInt(5)
  result.sawWolfSeat = -1
  result.sawClearSeat = -1
  result.robbedSeat = -1
  let you = view{"you"}
  if you == nil or you.kind != JObject:
    return
  result.dealtRole = you{"dealtRole"}.getStr()
  result.finalRole = result.dealtRole
  for fact in you{"observations"}.getElems():
    case fact{"kind"}.getStr()
    of "wolves":
      for wolfSeat in fact{"seats"}.getElems():
        result.fellowWolves.add(wolfSeat.getInt())
    of "wolfPeek":
      result.centerNote = "center " & $(fact{"center"}.getInt() + 1) &
        " holds " & roleLabel(fact{"role"}.getStr())
    of "seerPlayer":
      if fact{"role"}.getStr() == "werewolf":
        result.sawWolfSeat = fact{"seat"}.getInt()
      else:
        result.sawClearSeat = fact{"seat"}.getInt()
        result.sawClearRole = fact{"role"}.getStr()
    of "seerCenters":
      var parts: seq[string]
      for card in fact{"cards"}.getElems():
        parts.add("center " & $(card{"center"}.getInt() + 1) & " = " &
          roleLabel(card{"role"}.getStr()))
      result.centerNote = parts.join(", ")
    of "rob":
      result.robbedSeat = fact{"target"}.getInt()
      result.finalRole = fact{"role"}.getStr()
    of "insomniac":
      result.finalRole = fact{"role"}.getStr()
    else:
      discard

proc nightDecision(knowledge: Knowledge): JsonNode =
  ## The single night variant owed to our dealt role. Only roles with a
  ## night choice are ever asked.
  let nextSeat = (knowledge.seat + 1) mod knowledge.playerCount
  case knowledge.dealtRole
  of "werewolf":
    # Lone wolf (only then is a decision owed): peek a center card.
    %*{"kind": "wolfPeek", "center": 0}
  of "seer":
    # Inspect a player: it yields a public, actionable accusation.
    %*{"kind": "seer", "look": {"type": "player", "seat": nextSeat}}
  of "robber":
    # Rob: we learn (and become) the team we hold; the target turns village.
    %*{"kind": "rob", "target": nextSeat}
  of "troublemaker":
    # A blind swap scrambles our own vote logic more than the wolves'.
    %*{"kind": "troublemaker", "swap": newJNull()}
  else:
    # Never asked; a legal-shaped skip in case the host asks anyway.
    %*{"kind": "seer", "look": {"type": "skip"}}

proc speakText(view: JsonNode, knowledge: Knowledge): string =
  ## One short public statement. Village knowledge is shared verbatim (LLM
  ## tables act on named accusations); a wolf-holding seat bluffs Villager.
  if knowledge.finalRole == "werewolf":
    return "I am a plain Villager. I heard nothing all night and I will " &
      "vote with the table."
  case knowledge.dealtRole
  of "seer":
    if knowledge.sawWolfSeat >= 0:
      return "I am the Seer. I looked at " &
        seatName(view, knowledge.sawWolfSeat) &
        " and saw a WEREWOLF card. Vote " &
        seatName(view, knowledge.sawWolfSeat) & " with me."
    elif knowledge.sawClearSeat >= 0:
      return "I am the Seer. " & seatName(view, knowledge.sawClearSeat) &
        " held " & roleLabel(knowledge.sawClearRole) &
        " — they are clear. Look elsewhere for the wolf."
    elif knowledge.centerNote.len > 0:
      return "I am the Seer. I looked at the center: " &
        knowledge.centerNote & "."
  of "robber":
    if knowledge.robbedSeat >= 0:
      return "I am the Robber. I robbed " &
        seatName(view, knowledge.robbedSeat) & " and now hold " &
        roleLabel(knowledge.finalRole) & "; " &
        seatName(view, knowledge.robbedSeat) &
        " holds the Robber card and is village."
    return "I am the Robber but I robbed nobody — I am still village."
  of "troublemaker":
    return "I am the Troublemaker. I swapped nobody, so every card is " &
      "where it was dealt."
  of "insomniac":
    return "I am the Insomniac. At dawn I still hold " &
      roleLabel(knowledge.finalRole) & "."
  else:
    discard
  "I am a Villager with no night information. I will vote for the " &
    "strongest accusation on the table."

proc voteTarget(view: JsonNode, knowledge: Knowledge): int =
  ## Counterclaim of our unique dealt role first (strongest wolf signal),
  ## then seer-seen wolf, then the baseline's next-seat vote. Never self,
  ## never a known fellow wolf.
  let n = knowledge.playerCount
  if knowledge.finalRole == "werewolf":
    for candidate in 0 ..< n:
      let target = (knowledge.seat + 1 + candidate) mod n
      if target != knowledge.seat and target notin knowledge.fellowWolves:
        return target
  let accused = counterclaimSeat(view, knowledge)
  if accused >= 0 and accused != knowledge.seat:
    return accused
  if knowledge.sawWolfSeat >= 0 and knowledge.sawWolfSeat != knowledge.seat:
    return knowledge.sawWolfSeat
  for candidate in 0 ..< n:
    let target = (knowledge.seat + 1 + candidate) mod n
    if target == knowledge.seat:
      continue
    # Skip seats we positively know are village (seer-cleared / robbed).
    if target == knowledge.sawClearSeat or target == knowledge.robbedSeat:
      continue
    return target
  (knowledge.seat + 1) mod n

proc baselineDecision(view: JsonNode, knowledge: Knowledge): JsonNode =
  ## The upstream always-legal fallback, used after a rejected reply.
  case view{"phase"}.getStr()
  of "night":
    case knowledge.dealtRole
    of "werewolf": %*{"kind": "wolfPeek", "center": 0}
    of "seer": %*{"kind": "seer", "look": {"type": "player",
      "seat": (knowledge.seat + 1) mod knowledge.playerCount}}
    of "robber": %*{"kind": "rob", "target": newJNull()}
    else: %*{"kind": "troublemaker", "swap": newJNull()}
  of "day":
    %*{"kind": "speak", "text": "I have nothing to add."}
  else:
    %*{"kind": "vote",
       "target": (knowledge.seat + 1) mod knowledge.playerCount}

proc decide(view: JsonNode, seat: int, rejected: bool): JsonNode =
  let knowledge = digest(view, seat)
  if rejected:
    return baselineDecision(view, knowledge)
  case view{"phase"}.getStr()
  of "night":
    nightDecision(knowledge)
  of "day":
    %*{"kind": "speak", "text": speakText(view, knowledge)}
  of "vote":
    %*{"kind": "vote", "target": voteTarget(view, knowledge)}
  else:
    baselineDecision(view, knowledge)

proc main() =
  let client = newCoworldClient("volkolak")
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      echo "volkolak: seated slot ", message{"slot"}.getInt()
    of "observation":
      let rejected = message{"reason"} != nil and
        message{"reason"}.kind == JString
      let decision = decide(message["view"], message{"seat"}.getInt(),
        rejected)
      client.send(%*{"type": "reply", "id": message["id"],
                     "decision": decision})
    of "final":
      echo "volkolak: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
