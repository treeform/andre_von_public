## Hosted XP activation extractor for Buyan experiment logs and replays.
## Emits the statistics activation JSON. Local files are not scores.

import
  std/[json, os, sets, strutils, tables],
  replays

const
  EvidenceSource = "softmax-hosted-xp"
  ArmorPrefix = "armor_upgrade "
  CleanPrefix = "buyan-clean "
  MaxActionId = 25
  MinKeyAction = 8
  MaxKeyAction = 16
  ArmorSlots = ["helm", "chest", "legs"]
  CleanMetric =
    "Clean adapter counted individually replay-verified activation " &
    "markers whose action differs from baselineAction and matches the " &
    "replay. trigger_count is a verified lower bound, not all clean " &
    "changes; summary counters are not added without individual replay " &
    "tick proof. This is a trust-only counterfactual on the same clean " &
    "observation, not a full baseline run. No combat, item, or movement " &
    "success is claimed."
  HuntMetric =
    "Hunt adapter counted issued walk or stage events with changed true " &
    "whose action matches the replay. No combat, item, or movement " &
    "success is claimed."
  EscapeMetric =
    "Escape adapter counted escape_issue events whose action differs " &
    "from baselineAction and matches the replay. Any action in 0..25 is " &
    "accepted after a fallback. No combat, item, or movement success is " &
    "claimed."
  SwordMetric =
    "Sword adapter counted strategy_action events whose candidateAction " &
    "differs from baselineAction and matches the replay. Counterfactual " &
    "is unchanged action choice on a copied current Mind, not a " &
    "separate baseline trajectory. held_issued, held_confirmed, " &
    "held_failed, attack_issued, and attack_feedback do not count. No " &
    "combat, item, or movement success is claimed."
  ArmorMetric =
    "Armor adapter counted armor_upgrade issued events whose inventory " &
    "key matches the replay. This action unequips currently worn armor; " &
    "unchanged baseline equipAction never emits an already-equipped " &
    "armor key. No combat, item, or movement success is claimed."

type
  NmmoActivationError* = object of CatchableError
  ExperimentKind = enum
    CleanExp
    HuntExp
    EscapeExp
    SwordExp
    ArmorExp
  Plan = object
    source: string
    experiment: string
    kind: ExperimentKind
    coworldId: string
    coworldVersion: string
    candidatePolicyVersionId: string
    xpIds: HashSet[string]
  EvidenceEpisode = object
    xpId: string
    episodeId: string
    candidatePosition: int
    logPath: string
    replayPath: string
  EvidenceDoc = object
    source: string
    episodes: seq[EvidenceEpisode]
  CountState = object
    count: int
    seen: HashSet[(int, int)]

proc fail(message: string) {.noReturn, raises: [NmmoActivationError].} =
  ## Raise NmmoActivationError with a useful message.
  raise newException(NmmoActivationError, message)

proc requireObject(node: JsonNode, message: string): JsonNode
    {.raises: [NmmoActivationError].} =
  ## Return node when it is a JSON object, otherwise raise.
  if node.isNil or node.kind != JObject:
    fail(message)
  node

proc requireArray(node: JsonNode, message: string): JsonNode
    {.raises: [NmmoActivationError].} =
  ## Return node when it is a JSON array, otherwise raise.
  if node.isNil or node.kind != JArray:
    fail(message)
  node

proc requireString(node: JsonNode, field, context: string): string
    {.raises: [NmmoActivationError].} =
  ## Require a nonempty JSON string field.
  let n = node{field}
  if n.isNil or n.kind != JString:
    fail(context & "expected string field " & field)
  result = n.getStr
  if result.len == 0:
    fail(context & "field " & field & " must be nonempty")

proc requireInt(node: JsonNode, field, context: string): int
    {.raises: [NmmoActivationError].} =
  ## Require an exact JSON integer field, not a float or bool.
  let n = node{field}
  if n.isNil or n.kind != JInt:
    fail(context & "expected integer field " & field)
  n.getInt

proc requireBool(node: JsonNode, field, context: string): bool
    {.raises: [NmmoActivationError].} =
  ## Require an exact JSON boolean field.
  let n = node{field}
  if n.isNil or n.kind != JBool:
    fail(context & "expected boolean field " & field)
  n.getBool

proc parseExperiment(name: string): ExperimentKind
    {.raises: [NmmoActivationError].} =
  ## Map a plan experiment name onto a known adapter kind.
  case name
  of "clean":
    CleanExp
  of "hunt":
    HuntExp
  of "escape":
    EscapeExp
  of "sword":
    SwordExp
  of "armor":
    ArmorExp
  else:
    fail("unsupported experiment '" & name &
      "'; expected clean, hunt, escape, sword, or armor")

proc metricFor(kind: ExperimentKind): string {.raises: [].} =
  ## Return the adapter metric text. Never claims success or KEEP.
  case kind
  of CleanExp:
    CleanMetric
  of HuntExp:
    HuntMetric
  of EscapeExp:
    EscapeMetric
  of ArmorExp:
    ArmorMetric
  of SwordExp:
    SwordMetric

proc loadJsonFile(path: string): JsonNode {.raises: [NmmoActivationError].} =
  ## Read a JSON file and map I/O or parse failures to NmmoActivationError.
  var text: string
  try:
    text = readFile(path)
  except IOError as err:
    fail("cannot read " & path & ": " & err.msg)
  except OSError as err:
    fail("cannot read " & path & ": " & err.msg)
  try:
    result = parseJson(text)
  except JsonParsingError as err:
    fail("cannot parse JSON " & path & ": " & err.msg)
  except ValueError as err:
    fail("cannot parse JSON " & path & ": " & err.msg)
  except IOError as err:
    fail("cannot parse JSON " & path & ": " & err.msg)
  except OSError as err:
    fail("cannot parse JSON " & path & ": " & err.msg)

proc parsePlan(node: JsonNode): Plan {.raises: [NmmoActivationError].} =
  ## Validate stats-plan membership fields used by activation output.
  discard requireObject(node, "plan must be a JSON object")
  result.source = requireString(node, "source", "plan: ")
  result.experiment = requireString(node, "experiment", "plan: ")
  result.kind = parseExperiment(result.experiment)
  result.coworldId = requireString(node, "coworld_id", "plan: ")
  result.coworldVersion = requireString(node, "coworld_version", "plan: ")
  let candidate = requireObject(
    node{"candidate"}, "plan missing candidate object")
  result.candidatePolicyVersionId = requireString(
    candidate, "policy_version_id", "plan.candidate: ")
  let requests = requireArray(node{"requests"}, "plan missing requests array")
  for i, req in requests.elems:
    let row = requireObject(req, "plan.requests[" & $i & "] must be an object")
    let xpId = requireString(row, "xp_id", "plan.requests[" & $i & "]: ")
    if xpId in result.xpIds:
      fail("duplicate plan xp_id " & xpId)
    result.xpIds.incl xpId

proc parseEvidence(
  node: JsonNode, xpIds: HashSet[string]
): EvidenceDoc {.raises: [NmmoActivationError].} =
  ## Validate evidence membership, types, nonempty paths, and uniqueness.
  discard requireObject(node, "evidence must be a JSON object")
  result.source = requireString(node, "source", "evidence: ")
  if result.source != EvidenceSource:
    fail("evidence source must be " & EvidenceSource)
  let episodes = requireArray(
    node{"episodes"}, "evidence missing episodes array")
  var seenIds: HashSet[string]
  for i, item in episodes.elems:
    let ctx = "evidence.episodes[" & $i & "]: "
    let row = requireObject(item, ctx & "must be an object")
    var ep: EvidenceEpisode
    ep.xpId = requireString(row, "xp_id", ctx)
    ep.episodeId = requireString(row, "episode_id", ctx)
    ep.candidatePosition = requireInt(row, "candidate_position", ctx)
    if ep.candidatePosition < 0:
      fail(ctx & "candidate_position must be nonnegative")
    ep.logPath = requireString(row, "log_path", ctx)
    ep.replayPath = requireString(row, "replay_path", ctx)
    if ep.xpId notin xpIds:
      fail("unknown xp_id " & ep.xpId)
    if ep.episodeId in seenIds:
      fail("duplicate episode_id " & ep.episodeId)
    seenIds.incl ep.episodeId
    result.episodes.add ep

proc resolvePath(baseDir, path: string): string {.raises: [].} =
  ## Resolve a relative evidence path against the evidence file directory.
  if path.isAbsolute:
    path
  else:
    baseDir / path

proc loadReplayWrapped(path: string): Replay
    {.raises: [NmmoActivationError].} =
  ## Load a replay and wrap parser or I/O failures.
  try:
    result = loadReplay(path)
  except NmmoReplayError as err:
    fail("replay failure for " & path & ": " & err.msg)

proc replayAction(replay: Replay, tick, agent: int): int
    {.raises: [NmmoActivationError].} =
  ## Look up one replay action and wrap range errors.
  try:
    result = action(replay, tick, agent)
  except NmmoReplayError as err:
    fail("replay action lookup failed: " & err.msg)

proc checkReplayMatch(
  replay: Replay, position, tick, agent, act: int
) {.raises: [NmmoActivationError].} =
  ## Require the replay body action equals the candidate marker action.
  let globalAgent = position * replay.heroesPerSeat + agent
  let actual = replayAction(replay, tick, globalAgent)
  if actual != act:
    fail("replay action mismatch at tick " & $tick &
      " seat " & $position & " agent " & $agent &
      ": marker action " & $act & " actual " & $actual)

proc considerMarker(
  state: var CountState,
  replay: Replay,
  position, tick, agent, act: int,
  countable: bool
) {.raises: [NmmoActivationError].} =
  ## Validate one candidate marker and count it when it is a difference.
  if tick < 0 or tick >= replay.tickCount:
    fail("tick " & $tick & " is not in replay range")
  if agent < 0 or agent >= replay.heroesPerSeat:
    fail("agent " & $agent & " is not a local seat agent")
  if act < 0 or act > MaxActionId:
    fail("action out of range 0..25")
  checkReplayMatch(replay, position, tick, agent, act)
  if not countable:
    return
  let key = (tick, agent)
  if key in state.seen:
    fail("duplicate countable marker at tick " & $tick &
      " agent " & $agent)
  state.seen.incl key
  inc state.count

proc requireBaseline(
  node: JsonNode, context: string
): int {.raises: [NmmoActivationError].} =
  ## Require baselineAction in 0..25. Missing field is fatal.
  result = requireInt(node, "baselineAction", context)
  if result < 0 or result > MaxActionId:
    fail(context & "baselineAction out of range 0..25")

proc parseJsonLine(text: string, lineNo: int): JsonNode
    {.raises: [NmmoActivationError].} =
  ## Parse one JSON log line. Malformed JSON is fatal.
  try:
    result = parseJson(text)
  except JsonParsingError as err:
    fail("malformed JSON on log line " & $lineNo & ": " & err.msg)
  except ValueError as err:
    fail("malformed JSON on log line " & $lineNo & ": " & err.msg)
  except IOError as err:
    fail("malformed JSON on log line " & $lineNo & ": " & err.msg)
  except OSError as err:
    fail("malformed JSON on log line " & $lineNo & ": " & err.msg)

proc parseCleanMarker(
  node: JsonNode,
  replay: Replay,
  position: int,
  state: var CountState,
  context: string
) {.raises: [NmmoActivationError].} =
  ## Count a verified clean activation counterfactual difference.
  let experiment = requireString(node, "experiment", context)
  if experiment != "clean":
    fail(context & "experiment must be clean")
  let
    tick = requireInt(node, "tick", context)
    agent = requireInt(node, "agent", context)
    act = requireInt(node, "action", context)
    baseline = requireBaseline(node, context)
    verifiedClean = requireBool(node, "verifiedClean", context)
    clearedCells = requireInt(node, "clearedCells", context)
    extraHints = requireInt(node, "extraHints", context)
    counterfactual = requireString(node, "counterfactual", context)
  if counterfactual != "trust-only":
    fail(context & "counterfactual must be trust-only")
  if not verifiedClean:
    fail(context & "verifiedClean must be true")
  if clearedCells <= 0:
    fail(context & "clearedCells must be > 0")
  if extraHints < 0:
    fail(context & "extraHints must be >= 0")
  if act == baseline:
    fail(context & "clean activation requires action != baselineAction")
  considerMarker(state, replay, position, tick, agent, act, true)

proc parseHuntMarker(
  node: JsonNode,
  replay: Replay,
  position: int,
  state: var CountState,
  context: string
) {.raises: [NmmoActivationError].} =
  ## Count hunt issued walk/stage events only when changed is true.
  let experiment = requireString(node, "experiment", context)
  if experiment != "hunt":
    fail(context & "experiment must be hunt")
  let
    tick = requireInt(node, "tick", context)
    agent = requireInt(node, "agent", context)
    act = requireInt(node, "action", context)
    baseline = requireBaseline(node, context)
    changed = requireBool(node, "changed", context)
    kind = requireString(node, "kind", context)
  if kind != "walk" and kind != "stage":
    fail(context & "kind must be walk or stage")
  if changed != (act != baseline):
    fail(context & "changed must equal (action != baselineAction)")
  considerMarker(state, replay, position, tick, agent, act, changed)

proc parseEscapeMarker(
  node: JsonNode,
  replay: Replay,
  position: int,
  state: var CountState,
  context: string
) {.raises: [NmmoActivationError].} =
  ## Count escape_issue events whose action differs from baselineAction.
  let expNode = node{"experiment"}
  if not expNode.isNil:
    if expNode.kind != JString or expNode.getStr != "escape":
      fail(context & "experiment must be escape")
  let
    tick = requireInt(node, "tick", context)
    agent = requireInt(node, "agent", context)
    act = requireInt(node, "action", context)
    baseline = requireBaseline(node, context)
  considerMarker(
    state, replay, position, tick, agent, act, act != baseline)

proc parseSwordMarker(
  node: JsonNode,
  replay: Replay,
  position: int,
  state: var CountState,
  context: string
) {.raises: [NmmoActivationError].} =
  ## Count sword strategy_action differences; diagnostics do not count.
  let strategy = requireString(node, "strategy", context)
  if strategy != "sword":
    fail(context & "strategy must be sword")
  let
    tick = requireInt(node, "tick", context)
    agent = requireInt(node, "agent", context)
    generation = requireInt(node, "generation", context)
    step = requireInt(node, "step", context)
    act = requireInt(node, "candidateAction", context)
    baseline = requireBaseline(node, context)
  if generation < 0:
    fail(context & "generation must be >= 0")
  if step < 0:
    fail(context & "step must be >= 0")
  considerMarker(
    state, replay, position, tick, agent, act, act != baseline)

proc handleJsonMarker(
  kind: ExperimentKind,
  node: JsonNode,
  replay: Replay,
  position: int,
  state: var CountState,
  lineNo: int
) {.raises: [NmmoActivationError].} =
  ## Dispatch one JSON object to the plan's marker adapter.
  let eventNode = node{"event"}
  if eventNode.isNil:
    return
  if eventNode.kind != JString:
    fail("log line " & $lineNo & " event must be a string")
  let
    event = eventNode.getStr
    context = "log line " & $lineNo & ": "
  case kind
  of CleanExp:
    if event == "activation":
      parseCleanMarker(node, replay, position, state, context)
  of HuntExp:
    if event == "issued":
      parseHuntMarker(node, replay, position, state, context)
  of EscapeExp:
    if event == "escape_issue":
      parseEscapeMarker(node, replay, position, state, context)
  of SwordExp:
    if event == "strategy_action":
      parseSwordMarker(node, replay, position, state, context)
  of ArmorExp:
    discard

proc parseNonnegIntToken(raw, field, context: string): int
    {.raises: [NmmoActivationError].} =
  ## Parse a base-10 non-negative integer token.
  if raw.len == 0 or not raw.allCharsInSet(Digits):
    fail(context & "armor field " & field &
      " must be a non-negative integer")
  try:
    result = parseInt(raw)
  except ValueError as err:
    fail(context & "armor field " & field & " is not an integer: " &
      err.msg)

proc parseArmorFields(
  payload, context: string
): Table[string, string] {.raises: [NmmoActivationError].} =
  ## Parse space-delimited key=value tokens from an armor_upgrade line.
  result = initTable[string, string]()
  for token in payload.split(' '):
    if token.len == 0:
      continue
    let eq = token.find('=')
    if eq <= 0 or eq == token.high:
      fail(context & "malformed armor_upgrade key=value token")
    let
      key = token[0 ..< eq]
      val = token[eq + 1 .. ^1]
    if result.hasKey(key):
      fail(context & "duplicate armor field " & key)
    result[key] = val

proc armorField(
  fields: Table[string, string], key, context: string
): string {.raises: [NmmoActivationError].} =
  ## Fetch a required armor key=value field without raising KeyError.
  result = fields.getOrDefault(key)
  if result.len == 0:
    fail(context & "malformed issued armor_upgrade line")

proc parseArmorIssued(
  payload: string,
  replay: Replay,
  position: int,
  state: var CountState,
  lineNo: int
) {.raises: [NmmoActivationError].} =
  ## Count a well-formed armor_upgrade issued unequip. Other events do not.
  let context = "log line " & $lineNo & ": "
  let fields = parseArmorFields(payload, context)
  let event = fields.getOrDefault("event")
  if event.len == 0:
    fail(context & "malformed armor_upgrade line missing event")
  if event != "issued":
    return
  let
    tick = parseNonnegIntToken(armorField(fields, "tick", context), "tick", context)
    agent = parseNonnegIntToken(armorField(fields, "agent", context), "agent", context)
    act = parseNonnegIntToken(armorField(fields, "action", context), "action", context)
    slot = armorField(fields, "slot", context)
    oldTier = parseNonnegIntToken(
      armorField(fields, "oldTier", context), "oldTier", context)
    desiredTier = parseNonnegIntToken(
      armorField(fields, "desiredTier", context), "desiredTier", context)
    freshTier = parseNonnegIntToken(
      armorField(fields, "freshTier", context), "freshTier", context)
  if act < MinKeyAction or act > MaxKeyAction:
    fail(context & "armor action must be in 8..16")
  if slot notin ArmorSlots:
    fail(context & "armor slot must be helm, chest, or legs")
  if oldTier < 1:
    fail(context & "oldTier must be >= 1")
  if desiredTier <= oldTier:
    fail(context & "desiredTier must be > oldTier")
  if freshTier != oldTier:
    fail(context & "freshTier must equal oldTier")
  considerMarker(state, replay, position, tick, agent, act, true)

proc hexNibble(c: char): int {.raises: [NmmoActivationError].} =
  ## Decode one hex digit for a Python bytes-repr \\xHH escape.
  case c
  of '0'..'9':
    ord(c) - ord('0')
  of 'a'..'f':
    ord(c) - ord('a') + 10
  of 'A'..'F':
    ord(c) - ord('A') + 10
  else:
    fail("malformed bytes-repr hex escape")

proc decodePythonBytesRepr*(text: string): string
    {.raises: [NmmoActivationError].} =
  ## Decode one optional Python bytes-repr wrapper; leave plain text.
  var i = 0
  while i < text.len and text[i] in {' ', '\t'}:
    inc i
  if i + 1 >= text.len or text[i] != 'b' or
      (text[i + 1] != '\'' and text[i + 1] != '"'):
    return text
  let quote = text[i + 1]
  i += 2
  result = newStringOfCap(text.len)
  while i < text.len:
    let c = text[i]
    if c == quote:
      inc i
      while i < text.len:
        if text[i] notin {' ', '\t', '\r', '\n'}:
          fail("bytes-repr has trailing bytes after closing quote")
        inc i
      return
    if c == '\\':
      inc i
      if i >= text.len:
        fail("malformed bytes-repr escape at end of input")
      let e = text[i]
      case e
      of '\\':
        result.add '\\'
      of '\'':
        result.add '\''
      of '"':
        result.add '"'
      of 'n':
        result.add '\n'
      of 'r':
        result.add '\r'
      of 't':
        result.add '\t'
      of 'x':
        if i + 2 >= text.len:
          fail("malformed bytes-repr hex escape")
        let hi = hexNibble(text[i + 1])
        let lo = hexNibble(text[i + 2])
        result.add char((hi shl 4) or lo)
        i += 2
      else:
        fail("unknown bytes-repr escape")
      inc i
    else:
      result.add c
      inc i
  fail("bytes-repr missing closing quote")

proc parseLogText(
  text: string,
  kind: ExperimentKind,
  replay: Replay,
  position: int
): int {.raises: [NmmoActivationError].} =
  ## Inspect complete stdout lines and count countable candidate markers.
  let decoded = decodePythonBytesRepr(text)
  var
    state: CountState
    lineNo = 0
  for line in decoded.splitLines:
    inc lineNo
    let trimmed = strip(line)
    if trimmed.len == 0:
      continue
    var payload = trimmed
    var hasArmorPrefix = false
    var hasCleanPrefix = false
    if payload.startsWith(CleanPrefix):
      hasCleanPrefix = true
      payload = strip(payload[CleanPrefix.len .. ^1])
      if payload.len == 0:
        continue
    elif payload.startsWith(ArmorPrefix):
      hasArmorPrefix = true
      payload = strip(payload[ArmorPrefix.len .. ^1])
      if payload.len == 0:
        continue
    if payload[0] == '{' or payload[0] == '[':
      let node = parseJsonLine(payload, lineNo)
      if node.kind == JObject:
        if hasCleanPrefix:
          if kind == CleanExp:
            handleJsonMarker(kind, node, replay, position, state, lineNo)
        elif kind != CleanExp:
          handleJsonMarker(kind, node, replay, position, state, lineNo)
      continue
    if hasArmorPrefix and kind == ArmorExp:
      parseArmorIssued(payload, replay, position, state, lineNo)
  state.count

proc countEpisode(
  kind: ExperimentKind,
  logPath, replayPath: string,
  position: int
): int {.raises: [NmmoActivationError].} =
  ## Load one episode's log and replay and return the trigger count.
  let replay = loadReplayWrapped(replayPath)
  let seats = replay.numAgents div replay.heroesPerSeat
  if position >= seats:
    fail("candidate_position " & $position &
      " is not valid in replay with " & $seats & " seats")
  var text: string
  try:
    text = readFile(logPath)
  except IOError as err:
    fail("cannot read " & logPath & ": " & err.msg)
  except OSError as err:
    fail("cannot read " & logPath & ": " & err.msg)
  parseLogText(text, kind, replay, position)

proc activate*(planPath, evidencePath: string): JsonNode
    {.raises: [NmmoActivationError].} =
  ## Build stats activation JSON from a plan and local hosted evidence.
  let plan = parsePlan(loadJsonFile(planPath))
  let evidence = parseEvidence(loadJsonFile(evidencePath), plan.xpIds)
  if plan.source != EvidenceSource:
    fail("plan source must be " & EvidenceSource)
  if evidence.source != plan.source:
    fail("evidence source does not match plan source")
  var evidenceAbs: string
  try:
    evidenceAbs = absolutePath(evidencePath)
  except ValueError as err:
    fail("cannot resolve evidence path " & evidencePath & ": " & err.msg)
  except OSError as err:
    fail("cannot resolve evidence path " & evidencePath & ": " & err.msg)
  let baseDir = parentDir(evidenceAbs)
  result = newJObject()
  result["source"] = %plan.source
  result["experiment"] = %plan.experiment
  result["coworld_id"] = %plan.coworldId
  result["coworld_version"] = %plan.coworldVersion
  result["candidate_policy_version_id"] = %plan.candidatePolicyVersionId
  var episodes = newJArray()
  for ep in evidence.episodes:
    let
      logPath = resolvePath(baseDir, ep.logPath)
      replayPath = resolvePath(baseDir, ep.replayPath)
      triggerCount = countEpisode(
        plan.kind, logPath, replayPath, ep.candidatePosition)
    var row = newJObject()
    row["xp_id"] = %ep.xpId
    row["episode_id"] = %ep.episodeId
    row["candidate_position"] = %ep.candidatePosition
    row["verified"] = %(triggerCount > 0)
    row["trigger_count"] = %triggerCount
    row["log_path"] = %ep.logPath
    row["metric"] = %metricFor(plan.kind)
    row["replay_path"] = %ep.replayPath
    episodes.add row
  result["episodes"] = episodes
