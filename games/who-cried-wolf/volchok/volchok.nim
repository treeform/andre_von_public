## Volchok, Mafia: Who Cried Wolf? (nine seats, NewD3) policy for
## Andre von Auto. Command player on wcw.player/1: the game sends one
## observation per open request (bid, wolf_chat, noble_chat, vote, night,
## dead_chat) and Volchok answers each one right away.
##
## Volchok reads behaviour, never the words of chat. Every decision comes
## from roles, death reveals, private results, the public ballots, and the
## social graph of who accuses whom, folded into an exact posterior
## (beliefs.nim). A per-player stat engine (Profile) keeps each seat's
## record: accusations made and received, ballots, abstentions, votes and
## pushes on players who flipped town or wolf, and today's wagon support.
## Town seats join the most wolf-likely wagon that can land, accuse in
## nearly every speech with a concrete reason from that record, reply to
## whoever accuses them, and report the posterior with every vote. Wolf
## seats push the biggest town wagon, kill whoever hunts the pack, and
## never claim a role. No LLM, no secrets.

import
  std/[hashes, json, math, os, strutils],
  whisky, beliefs

const
  Protocol = "wcw.player/1"
  ReconnectAttempts = 20
  SpeechLimit = 470

type
  Talk = object
    id: string
    day: int
    speaker: int
    target: int

  Profile = object
    accusationsMade: int
    accusedToday: int
    accusedTotal: int
    accusedUs: int
    accusedUsToday: bool
    ballots: int
    abstains: int
    votesReceived: int
    votedRevealedTown: int
    votedTownName: string
    accusedRevealedTown: int
    accusedTownName: string
    accusedRevealedWolf: int
    withMajority: int
    votedPack: int
    accusedPack: int
    spokeToday: int
    support: float
    lastTalkToday: string

var finished = false

proc intOr(node: JsonNode, fallback: int): int =
  ## Returns an integer field value, or the fallback for null or missing.
  if node != nil and node.kind == JInt:
    return node.getInt()
  fallback

proc items(node: JsonNode, key: string): seq[JsonNode] =
  ## Returns the elements of an array field, or nothing.
  let value = node{key}
  if value != nil and value.kind == JArray:
    for item in value:
      result.add item

proc clip(text: string, limit: int): string =
  ## Trims text to a character limit and drops control characters.
  for ch in text:
    if ch >= ' ' or ch.ord >= 128:
      result.add ch
  if result.len > limit:
    result = result[0 ..< limit]
    while result.len > 0 and result[^1].ord >= 128:
      result.setLen(result.len - 1)

proc pick(k: Knowledge, salt: string, slots: seq[int]): int =
  ## Picks a stable pseudo-random slot for this episode, day and salt.
  if slots.len == 0:
    return -1
  let h = hash(k.episode & ":" & $k.day & ":" & $k.slot & ":" & salt)
  slots[(h and 0x7fffffff) mod slots.len]

proc variant(k: Knowledge, salt: string, count: int): int =
  ## Picks a stable phrasing index for this episode, day and salt.
  let h = hash(k.episode & ":" & $k.day & ":" & $k.slot & ":" & salt)
  (h and 0x7fffffff) mod max(1, count)

proc living(k: Knowledge): seq[int] =
  ## Returns every living slot.
  for i in 0 ..< Seats:
    if k.alive[i]:
      result.add i

proc others(k: Knowledge): seq[int] =
  ## Returns every living slot except our own.
  for i in 0 ..< Seats:
    if k.alive[i] and i != k.slot:
      result.add i

proc isPack(k: Knowledge, slot: int): bool =
  ## True when the slot belongs to our known wolf pack.
  slot in k.pack

proc revealedTown(k: Knowledge, slot: int): bool =
  ## True when a dead seat flipped town.
  not k.alive[slot] and k.fixed[slot] >= 0 and
    Role(k.fixed[slot]) notin WolfRoles

proc revealedWolf(k: Knowledge, slot: int): bool =
  ## True when a dead seat flipped wolf.
  not k.alive[slot] and k.fixed[slot] >= 0 and
    Role(k.fixed[slot]) in WolfRoles

proc digest(observation: JsonNode): (Knowledge, seq[Talk]) =
  ## Turns one observation into what this seat knows and the talk graph.
  ## Only who accuses whom is read from speech, never the words.
  let me = observation{"self"}
  var
    k = newKnowledge(
      me{"slot"}.intOr(0),
      parseRole(me{"role"}.getStr())
    )
    talks: seq[Talk]
  k.episode = observation{"episodeId"}.getStr()
  k.day = observation{"day"}.intOr(1)
  for seat in observation.items("roster"):
    let i = seat{"slot"}.intOr(-1)
    if i in 0 ..< Seats:
      k.alive[i] = seat{"alive"}.getBool()
      k.names[i] = seat{"name"}.getStr(k.names[i])
  for mate in observation.items("teammates"):
    let i = mate{"slot"}.intOr(-1)
    if i in 0 ..< Seats:
      let role = parseRole(mate{"role"}.getStr())
      k.fix(i, role)
      if role in WolfRoles:
        k.pack.add i
  for event in observation.items("transcript"):
    let
      payload = event{"payload"}
      day = event{"day"}.intOr(0)
    case payload{"kind"}.getStr()
    of "elimination":
      let i = payload{"slot"}.intOr(-1)
      if i in 0 ..< Seats:
        k.deathCause[i] = payload{"cause"}.getStr()
        k.deathDay[i] = day
        if payload{"role"} != nil and payload{"role"}.kind == JString:
          k.fix(i, parseRole(payload{"role"}.getStr()))
    of "speech":
      let
        speech = payload{"speech"}
        speaker = speech{"slot"}.intOr(-1)
        target = speech{"accusation"}.intOr(-1)
      if speaker notin 0 ..< Seats:
        continue
      talks.add Talk(
        id: event{"id"}.getStr(),
        day: day,
        speaker: speaker,
        target: target
      )
      if target in 0 ..< Seats and target != speaker:
        let accusation = Accusation(day: day, speaker: speaker,
          target: target)
        if accusation notin k.accusations:
          k.accusations.add accusation
    else:
      discard
  for row in observation.items("votes"):
    var round = VoteDay(day: row{"day"}.intOr(0))
    for ballot in row.items("ballots"):
      let voter = ballot{"slot"}.intOr(-1)
      if voter in 0 ..< Seats:
        round.ballots.add Ballot(
          voter: voter,
          target: ballot{"target"}.intOr(-1)
        )
    k.votes.add round
  for item in observation.items("privateResults"):
    let
      ability = item{"ability"}.getStr()
      target = item{"target"}.intOr(-1)
      day = item{"day"}.intOr(0)
      outcome = item{"result"}
    if target notin 0 ..< Seats:
      continue
    case ability
    of "inspect":
      k.inspected[target] = true
      if outcome.getStr() == "wolf":
        k.wolfSide[target] = 1
      elif outcome.getStr() == "not_wolf":
        k.wolfSide[target] = 0
    of "check":
      let text = outcome.getStr()
      if text == "vanilla":
        k.checked[target] = Sheep.ord
      elif text != "no_result" and text.len > 0:
        k.checked[target] = parseRole(text).ord
    of "inform":
      k.fix(target, DairyMaid)
    of "track":
      k.tracked[target] = true
      if outcome.kind == JArray and outcome.len > 0:
        k.active[target] = true
        for visit in outcome:
          let v = visit.intOr(-1)
          if v in 0 ..< Seats and k.deathCause[v] == "wolf" and
            k.deathDay[v] == day:
              k.wolfHint[target] = 3.0
              k.priestCatch = target
              k.priestVictim = v
    else:
      discard
  (k, talks)

proc profiles(
  k: Knowledge,
  talks: seq[Talk],
  beliefs: array[Seats, float]
): array[Seats, Profile] =
  ## Builds every seat's record from ballots, accusations, and reveals.
  for round in k.votes:
    var counts: array[Seats, int]
    for ballot in round.ballots:
      if ballot.target in 0 ..< Seats:
        inc counts[ballot.target]
    var
      leader = -1
      best = 0
      tied = false
    for i in 0 ..< Seats:
      if counts[i] > best:
        best = counts[i]
        leader = i
        tied = false
      elif counts[i] == best and best > 0:
        tied = true
    if tied:
      leader = -1
    for ballot in round.ballots:
      let
        voter = ballot.voter
        target = ballot.target
      if target < 0:
        inc result[voter].abstains
        continue
      inc result[voter].ballots
      inc result[target].votesReceived
      if target == leader:
        inc result[voter].withMajority
      if k.isPack(target):
        inc result[voter].votedPack
      if k.revealedTown(target):
        inc result[voter].votedRevealedTown
        result[voter].votedTownName = k.names[target]
  for accusation in k.accusations:
    let
      speaker = accusation.speaker
      target = accusation.target
    inc result[speaker].accusationsMade
    inc result[target].accusedTotal
    if k.isPack(target):
      inc result[speaker].accusedPack
    if target == k.slot:
      inc result[speaker].accusedUs
      if accusation.day == k.day:
        result[speaker].accusedUsToday = true
    if k.revealedTown(target):
      inc result[speaker].accusedRevealedTown
      result[speaker].accusedTownName = k.names[target]
    if k.revealedWolf(target):
      inc result[speaker].accusedRevealedWolf
    if accusation.day == k.day and speaker != k.slot:
      inc result[target].accusedToday
      result[target].support += 1 - beliefs[speaker]
  for talk in talks:
    if talk.day == k.day:
      inc result[talk.speaker].spokeToday
      result[talk.speaker].lastTalkToday = talk.id

proc baseline(k: Knowledge, beliefs: array[Seats, float]): float =
  ## Returns the know-nothing wolf rate among the other living players.
  var wolves = 0.0
  for i in k.others():
    wolves += beliefs[i]
  wolves / max(1, k.others().len).float

proc knownWolf(k: Knowledge, beliefs: array[Seats, float]): int =
  ## Returns a living slot that is certainly a wolf, or -1.
  for i in k.others():
    if beliefs[i] > 0.999:
      return i
  -1

proc mostLikely(
  k: Knowledge,
  beliefs: array[Seats, float],
  salt: string,
  pool: seq[int]
): int =
  ## Returns the pool slot most likely to be a wolf, ties broken stably.
  var
    best = -1.0
    tied: seq[int]
  for t in pool:
    if beliefs[t] > best + 1e-9:
      best = beliefs[t]
      tied = @[t]
    elif abs(beliefs[t] - best) <= 1e-9:
      tied.add t
  k.pick(salt, tied)

proc townTarget(
  k: Knowledge,
  beliefs: array[Seats, float],
  seen: array[Seats, Profile]
): int =
  ## Picks who town should accuse and vote: a known wolf, else the wagon
  ## with the most accusers today (two or more) unless we read that seat as
  ## town, else the top suspect (on a flat day: the most accused, then the
  ## quietest seat).
  let wolf = k.knownWolf(beliefs)
  if wolf >= 0:
    return wolf
  let chance = k.baseline(beliefs)
  var
    most = 1
    wagon = -1
  for i in k.others():
    if seen[i].accusedToday < 2 or beliefs[i] < chance * 0.75:
      continue
    if seen[i].accusedToday > most or
      (seen[i].accusedToday == most and beliefs[i] > beliefs[wagon]):
        most = seen[i].accusedToday
        wagon = i
  if wagon >= 0:
    return wagon
  var top = -1.0
  for i in k.others():
    top = max(top, beliefs[i])
  var pool: seq[int]
  for i in k.others():
    if beliefs[i] >= top - 0.02:
      pool.add i
  var
    mostAccused = -1
    quietest = high(int)
  for i in pool:
    mostAccused = max(mostAccused, seen[i].accusedToday)
  var narrowed: seq[int]
  for i in pool:
    if seen[i].accusedToday == mostAccused:
      narrowed.add i
      quietest = min(quietest, seen[i].spokeToday)
  var quiet: seq[int]
  for i in narrowed:
    if seen[i].spokeToday == quietest:
      quiet.add i
  k.pick("town-target", quiet)

proc hunters(k: Knowledge, seen: array[Seats, Profile],
    pool: seq[int]): seq[int] =
  ## Returns the pool seats that hunt our pack hardest.
  var most = 0
  for i in pool:
    let hunt = seen[i].accusedPack + seen[i].votedPack
    if hunt > most:
      most = hunt
      result = @[i]
    elif hunt == most and most > 0:
      result.add i

proc wolfTarget(k: Knowledge, seen: array[Seats, Profile]): int =
  ## Picks who a wolf should accuse and vote: the biggest town wagon, else
  ## whoever hunts the pack, else a stable town pick.
  var targets: seq[int]
  for i in k.others():
    if not k.isPack(i):
      targets.add i
  var
    most = 0
    wagons: seq[int]
  for i in targets:
    if seen[i].accusedToday > most:
      most = seen[i].accusedToday
      wagons = @[i]
    elif seen[i].accusedToday == most and most > 0:
      wagons.add i
  if wagons.len > 0:
    return k.pick("wolf-wagon", wagons)
  let hunting = k.hunters(seen, targets)
  if hunting.len > 0:
    return k.pick("wolf-hunter", hunting)
  k.pick("wolf-target", targets)

proc wolfBallot(k: Knowledge, seen: array[Seats, Profile]): int =
  ## Votes the wolf target, but drops a packmate already doomed by a
  ## wagon of half the table so the pack's ballots look like town's.
  let living = k.living().len
  for mate in k.pack:
    if mate != k.slot and k.alive[mate] and
      seen[mate].accusedToday * 2 >= living:
        return mate
  k.wolfTarget(seen)

proc killTarget(k: Knowledge, targets: seq[int],
    seen: array[Seats, Profile]): int =
  ## Chooses the night kill: checked threats, pack hunters, then voters.
  for role in ThreatRoles:
    for i in targets:
      if k.checked[i] == role.ord:
        return i
  let hunting = k.hunters(seen, targets)
  if hunting.len > 0:
    return k.pick("kill-hunter", hunting)
  var workers: seq[int]
  for i in targets:
    if seen[i].ballots + seen[i].accusationsMade > 0:
      workers.add i
  if workers.len > 0:
    return k.pick("kill-worker", workers)
  k.pick("kill", targets)

proc reasons(
  k: Knowledge,
  target: int,
  seen: array[Seats, Profile]
): seq[string] =
  ## Returns concrete behavioural reasons against one seat, best first.
  let
    name = k.names[target]
    record = seen[target]
  if record.votedRevealedTown > 0:
    result.add name & " voted " & record.votedTownName &
      ", who flipped town, and never owned that ballot"
  if record.accusedRevealedTown > 0:
    result.add name & " pushed " & record.accusedTownName &
      ", who flipped town, and moved on like nothing happened"
  if record.abstains > 0 and record.abstains >= record.ballots:
    result.add name & " keeps sitting out the vote, which is the cheapest " &
      "way for a wolf to stay clean"
  if record.ballots >= 2 and record.withMajority == 0:
    result.add name & "'s ballots never line up with anyone else's, " &
      "they vote where nobody can follow and explain nothing"
  if record.accusedToday >= 2:
    result.add $record.accusedToday & " of you raised " & name &
      " on your own today, and nothing in their ballots answers it"
  if record.accusationsMade == 0 and k.day >= 2:
    result.add name & " has not put a single name forward all game, " &
      "that is how wolves wait out the day"
  result.add name & "'s record is the one I trust least: their votes and " &
    "pushes don't add up to a town player"

proc clearest(
  k: Knowledge,
  beliefs: array[Seats, float],
  seen: array[Seats, Profile],
  target: int
): int =
  ## Returns a seat the social graph clears: it pushed a flipped wolf or
  ## the current target, and has the lowest wolf odds of those.
  result = -1
  var best = 2.0
  for i in k.others():
    if i == target or k.isPack(i):
      continue
    var pushed = seen[i].accusedRevealedWolf > 0
    for accusation in k.accusations:
      if accusation.speaker == i and accusation.target == target:
        pushed = true
    if pushed and beliefs[i] < best:
      best = beliefs[i]
      result = i

proc speech(
  k: Knowledge,
  beliefs: array[Seats, float],
  seen: array[Seats, Profile],
  turn: int
): (string, int, string) =
  ## Composes an accusatory speech, its accusation, and its replyTo id.
  let wolf = k.role in WolfRoles
  if k.role == Seer:
    let caught = k.knownWolf(beliefs)
    if caught >= 0 and k.wolfSide[caught] == 1:
      let name = k.names[caught]
      return ("I am the Seer. I checked " & name & " and they are a WOLF. " &
        "Vote " & name & " today, every ballot on " & name & ".", caught,
        seen[caught].lastTalkToday)
  if k.role == Priest and k.priestCatch >= 0 and k.alive[k.priestCatch]:
    let name = k.names[k.priestCatch]
    return ("I am the Priest. " & name & " visited " &
      k.names[k.priestVictim] & " the night they died. " & name &
      " holds the knife. Vote " & name & ".", k.priestCatch,
      seen[k.priestCatch].lastTalkToday)
  let target =
    if wolf: k.wolfTarget(seen) else: k.townTarget(beliefs, seen)
  if target < 0:
    return ("", -1, "")
  let
    name = k.names[target]
    why = k.reasons(target, seen)
    grounded = why.len > 1 or seen[target].accusedToday >= 2 or
      k.knownWolf(beliefs) == target
  if not grounded:
    const Waiting = [
      "No case I'd stake a vote on yet. I'm tracking who pushes names " &
        "with something behind them and who just echoes the room; my vote " &
        "follows the strongest concrete case.",
      "Too early for me to name a wolf honestly. What I weigh is the " &
        "record: who votes where, who changes targets, and who never " &
        "commits to anything.",
      "I'd rather build a case than invent one. Give me a ballot or a " &
        "push that doesn't fit a town player and I'll be on it."
    ]
    return (Waiting[k.variant("wait" & $turn, Waiting.len)], -1, "")
  let openers =
    if seen[target].accusedToday >= 2:
      @["I'm with the pressure on " & name & ". ",
        name & " is where my vote goes today. "]
    else:
      @["I'm voting " & name & ". ", "My vote today is " & name & ". "]
  var text = openers[k.variant("open" & $turn, openers.len)]
  let first = why[0]
  text.add first[0 .. 0].toUpperAscii() & first[1 .. ^1] & "."
  if why.len > 2:
    text.add " On top of that, " & why[1] & "."
  let clear = k.clearest(beliefs, seen, target)
  if clear >= 0 and not wolf:
    text.add " " & k.names[clear] & "'s pushes have lined up with the " &
      "evidence so far, which reads town to me."
  (text, target, seen[target].lastTalkToday)

proc nightActions(
  k: Knowledge,
  request: JsonNode,
  beliefs: array[Seats, float],
  seen: array[Seats, Profile]
): JsonNode =
  ## Fills every offered night ability in order with a legal target.
  result = newJArray()
  var killed = -1
  for choice in request.items("choices"):
    let ability = choice{"ability"}.getStr()
    var targets: seq[int]
    for t in choice.items("targets"):
      targets.add t.intOr(-1)
    var target = -1
    case ability
    of "kill":
      target = k.killTarget(targets, seen)
      killed = target
      var killer = k.slot
      for actor in choice.items("actors"):
        let a = actor.intOr(-1)
        if a != k.slot and a >= 0 and k.alive[a]:
          killer = a
          break
      result.add %*{"ability": ability, "target": target, "killer": killer}
      continue
    of "block":
      var pool: seq[int]
      for t in targets:
        if t != killed and not k.isPack(t):
          pool.add t
      target = k.killTarget(pool, seen)
    of "check":
      var pool: seq[int]
      for t in targets:
        if k.checked[t] < 0 and not k.isPack(t):
          pool.add t
      target = k.killTarget(if pool.len > 0: pool else: targets, seen)
    of "inspect":
      var pool: seq[int]
      for t in targets:
        if not k.inspected[t] and k.wolfSide[t] < 0:
          pool.add t
      target = k.mostLikely(beliefs, "inspect",
        if pool.len > 0: pool else: targets)
    of "protect", "inform":
      var safest = 2.0
      var pool: seq[int]
      for t in targets:
        let score = beliefs[t] -
          0.01 * float(seen[t].ballots + seen[t].accusationsMade > 0)
        if score < safest - 1e-9:
          safest = score
          pool = @[t]
        elif abs(score - safest) <= 1e-9:
          pool.add t
      target = k.pick(ability, pool)
    of "jail", "track":
      var pool: seq[int]
      for t in targets:
        if not (ability == "track" and k.tracked[t]) and beliefs[t] > 0:
          pool.add t
      target = k.mostLikely(beliefs, ability,
        if pool.len > 0: pool else: targets)
    else:
      target = k.pick(ability, targets)
    if target in targets:
      result.add %*{"ability": ability, "target": target}
    else:
      result.add %*{"ability": ability, "target": newJNull()}

proc nullSlot(slot: int): JsonNode =
  ## Encodes a slot, or null when negative.
  if slot >= 0: %slot else: newJNull()

proc decide(observation: JsonNode): JsonNode =
  ## Builds the action body for one observation.
  let
    request = observation{"request"}
    kind = request{"kind"}.getStr()
    retry = observation{"attempt"}.intOr(0) > 0
    (k, talks) = digest(observation)
  if retry or kind == "dead_chat":
    return nil
  # Public choices ignore accusations against us: voting or pushing our
  # own accuser reads as OMGUS to LLM tables. Private reports keep them.
  var shown = k
  shown.accusations = @[]
  for accusation in k.accusations:
    if accusation.target != k.slot:
      shown.accusations.add accusation
  let
    beliefs = k.posterior()
    public = shown.posterior()
    seen = k.profiles(talks, public)
  case kind
  of "bid":
    let (text, accusation, reply) = k.speech(public, seen,
      request{"window"}.intOr(0))
    if text.len == 0:
      return nil
    var replyTo = newJNull()
    for talk in talks:
      if talk.id == reply and reply.len > 0:
        replyTo = %reply
    let target =
      if accusation >= 0 and accusation != k.slot and k.alive[accusation]:
        accusation
      else:
        -1
    result = %*{"kind": "bid", "wantsToSpeak": true, "urgency": 2,
      "text": clip(text, SpeechLimit), "replyTo": replyTo,
      "accusation": nullSlot(target),
      "reason": "Push the seat the ballots and accusations point at."}
  of "wolf_chat":
    var targets: seq[int]
    for i in k.others():
      if not k.isPack(i):
        targets.add i
    let
      kill = k.killTarget(targets, seen)
      push = k.wolfTarget(seen)
    var text = "Volchok here."
    if kill >= 0 and push >= 0:
      text = "Kill " & k.names[kill] & " tonight. By day I push " &
        k.names[push] & "; join that wagon and never claim a role."
    result = %*{"kind": "wolf_chat", "text": clip(text, SpeechLimit),
      "summary": "Align the pack on one kill and one wagon."}
  of "noble_chat":
    let target = k.townTarget(public, seen)
    var text = "We are both Nobles, so both town."
    if target >= 0:
      text.add " I'm pushing " & k.names[target] & "; vote with me."
    result = %*{"kind": "noble_chat", "text": text,
      "summary": "Confirm the noble pair and share a target."}
  of "vote":
    var target =
      if k.role in WolfRoles: k.wolfBallot(seen)
      else: k.townTarget(public, seen)
    var targets: seq[int]
    for t in request.items("targets"):
      targets.add t.intOr(-1)
    if target notin targets or target == k.slot:
      target = -1
    result = %*{"kind": "vote", "target": nullSlot(target),
      "summary": "Vote the wagon the ballots and accusations support."}
    if request{"suspicion"} != nil and request{"suspicion"}.getBool():
      var reports = newJArray()
      for t in targets:
        if t != k.slot and k.alive[t]:
          let p = round(clamp(beliefs[t], 0.0, 1.0) * 10000) / 10000
          reports.add %*{"slot": t, "wolf": p}
      result["suspicion"] = reports
  of "night":
    result = %*{"kind": "night",
      "actions": k.nightActions(request, beliefs, seen),
      "summary": "Use every offered ability on the best target."}
  else:
    result = nil

proc fallback(request: JsonNode): JsonNode =
  ## Returns the always-legal pass for a request.
  case request{"kind"}.getStr()
  of "bid":
    %*{"kind": "bid", "wantsToSpeak": false, "urgency": 0, "text": "",
      "replyTo": newJNull(), "accusation": newJNull(), "reason": ""}
  of "wolf_chat", "noble_chat", "dead_chat":
    %*{"kind": request{"kind"}.getStr(), "text": "", "summary": ""}
  of "vote":
    %*{"kind": "vote", "target": newJNull(), "summary": ""}
  of "night":
    var actions = newJArray()
    for choice in request.items("choices"):
      actions.add %*{"ability": choice{"ability"}, "target": newJNull()}
    %*{"kind": "night", "actions": actions, "summary": ""}
  else:
    nil

proc handle(ws: WebSocket, message: JsonNode) =
  ## Answers observations and marks the episode finished on end.
  case message{"type"}.getStr()
  of "observation":
    var body: JsonNode
    try:
      body = decide(message)
    except CatchableError, Defect:
      echo "volchok: decision failed: ", getCurrentExceptionMsg()
      body = fallback(message{"request"})
    if body == nil:
      body = fallback(message{"request"})
    if body == nil:
      return
    ws.send($(%*{
      "protocol": Protocol,
      "type": "action",
      "episodeId": message{"episodeId"},
      "requestId": message{"requestId"},
      "observationId": message{"observationId"},
      "body": body,
      "report": newJNull()
    }))
  of "receipt":
    let status = message{"status"}.getStr()
    if status != "accepted" and status != "duplicate":
      echo "volchok: receipt ", message
  of "end":
    echo "volchok: end ", message{"result"}
    finished = true
  else:
    discard

proc play(url: string) =
  ## Plays over one connection until the end message or a socket failure.
  let ws = newWebSocket(url)
  defer:
    ws.close()
  while not finished:
    let received = ws.receiveMessage()
    if received.isNone:
      continue
    let message = received.get()
    case message.kind
    of Ping:
      ws.send(message.data, Pong)
    of TextMessage:
      var parsed: JsonNode
      try:
        parsed = parseJson(message.data)
      except CatchableError:
        continue
      handle(ws, parsed)
    else:
      discard

proc main() =
  ## Connects, plays, and re-dials the seat until the episode ends.
  let url = getEnv("COWORLD_PLAYER_WS_URL")
  if url.len == 0:
    quit("volchok: COWORLD_PLAYER_WS_URL is not set", 1)
  for attempt in 0 ..< ReconnectAttempts:
    try:
      echo "volchok: connecting to ", url
      play(url)
    except CatchableError, Defect:
      echo "volchok: connection failed: ", getCurrentExceptionMsg()
    if finished:
      break
    echo "volchok: re-dialling the seat (attempt ", attempt + 1, ")"
    sleep(1000)

main()
