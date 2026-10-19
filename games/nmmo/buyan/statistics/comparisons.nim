## Hosted XP paired comparison for one planned baseline/candidate field.
## Local saved JSON cannot prove network authenticity cryptographically.

import
  std/[algorithm, json, math, os, sets, tables]

const
  FamilyAlpha* = 0.05
  HypothesisCount* = 5
  LookSizes* = [10, 30, 100, 300]
  PerLookAlpha* = 0.0025
  ExpectedOpponentSeats* = 6
  SourceName* = "softmax-hosted-xp"
  MaxExactSignN* = 300
  AuthenticityNote* =
    "Local files cannot prove network authenticity cryptographically."
  LimitationNote* =
    "Sign-test inference describes the triggered subset and does not " &
    "by itself establish unconditional league improvement."
  DashboardNote* =
    "Dashboard significance must separately pass the user gate on the " &
    "identical field."

type
  BuyanError* = object of CatchableError
  PolicyRef* = object
    policyName*: string
    version*: int
    policyVersionId*: string
    seats*: int
  PlanRequest* = object
    xpId*: string
    episodesFile*: string
    episodeCount*: int
  Plan* = object
    source*: string
    experiment*: string
    coworldId*: string
    coworldVersion*: string
    baseline*: PolicyRef
    candidate*: PolicyRef
    opponents*: seq[PolicyRef]
    requests*: seq[PlanRequest]
    synthetic*: bool
  Activation* = object
    xpId*: string
    episodeId*: string
    candidatePosition*: int
    verified*: bool
    triggerCount*: int
    logPath*: string
    metric*: string
  LoadedEpisode = object
    id: string
    xpId: string
    jobIndex: int
    status: string
    baselinePos: int
    candidatePos: int
    node: JsonNode
  PairRow = object
    id: string
    xpId: string
    jobIndex: int
    baseline: float
    candidate: float
    diff: float
    triggers: int

proc fail(message: string) {.noreturn, raises: [BuyanError].} =
  ## Raises BuyanError with a concrete message.
  raise newException(BuyanError, message)

proc wrap(message: string, err: ref CatchableError) {.noreturn,
    raises: [BuyanError].} =
  ## Maps I/O, JSON, and coercion failures to BuyanError.
  fail(message & ": " & err.msg)

proc child(node: JsonNode, key: string): JsonNode {.raises: [].} =
  ## Returns a JSON object field or nil without raising KeyError.
  if node.isNil or node.kind != JObject:
    return nil
  node.getOrDefault(key)

proc reqKey(node: JsonNode, key, ctx: string): JsonNode {.raises: [BuyanError].} =
  ## Returns a required JSON field or fails closed.
  if node.isNil or node.kind != JObject:
    fail("Expected object in " & ctx)
  result = child(node, key)
  if result.isNil or result.kind == JNull:
    fail("Missing field " & key & " in " & ctx)

proc reqStr(node: JsonNode, key, ctx: string): string {.raises: [BuyanError].} =
  ## Reads a required JSON string.
  let value = reqKey(node, key, ctx)
  if value.kind != JString:
    fail("Field " & key & " must be a string in " & ctx)
  value.getStr

proc reqNonemptyStr(node: JsonNode, key, ctx: string): string {.
    raises: [BuyanError].} =
  ## Reads a required nonempty JSON string.
  result = reqStr(node, key, ctx)
  if result.len == 0:
    fail("Empty field " & key & " in " & ctx)

proc reqBool(node: JsonNode, key, ctx: string): bool {.raises: [BuyanError].} =
  ## Reads a required JSON bool.
  let value = reqKey(node, key, ctx)
  if value.kind != JBool:
    fail("Field " & key & " must be a boolean in " & ctx)
  value.getBool

proc reqInt(node: JsonNode, key, ctx: string): int {.raises: [BuyanError].} =
  ## Reads a required JSON integer.
  let value = reqKey(node, key, ctx)
  if value.kind != JInt:
    fail("Field " & key & " must be an integer in " & ctx)
  value.getInt

proc reqNonnegInt(node: JsonNode, key, ctx: string): int {.raises: [BuyanError].} =
  ## Reads a required nonnegative JSON integer.
  result = reqInt(node, key, ctx)
  if result < 0:
    fail("Field " & key & " must be nonnegative in " & ctx)

proc reqPosInt(node: JsonNode, key, ctx: string): int {.raises: [BuyanError].} =
  ## Reads a required positive JSON integer.
  result = reqInt(node, key, ctx)
  if result < 1:
    fail("Field " & key & " must be a positive integer in " & ctx)

proc reqObj(node: JsonNode, key, ctx: string): JsonNode {.raises: [BuyanError].} =
  ## Reads a required JSON object.
  result = reqKey(node, key, ctx)
  if result.kind != JObject:
    fail("Field " & key & " must be an object in " & ctx)

proc reqArr(node: JsonNode, key, ctx: string): seq[JsonNode] {.
    raises: [BuyanError].} =
  ## Reads a required JSON array.
  let value = reqKey(node, key, ctx)
  if value.kind != JArray:
    fail("Field " & key & " must be an array in " & ctx)
  value.getElems

proc isFiniteNumber(x: float): bool {.raises: [].} =
  ## Reports whether x is a finite float.
  classify(x) in {fcNormal, fcSubnormal, fcZero, fcNegZero}

proc reqFinite(x: float, ctx: string) {.raises: [BuyanError].} =
  ## Rejects NaN, Inf, and overflowed aggregates.
  if not isFiniteNumber(x):
    fail("Non-finite numeric value in " & ctx)

proc addFinite(a, b: float, ctx: string): float {.raises: [BuyanError].} =
  ## Adds two floats and rejects overflow.
  result = a + b
  reqFinite(result, ctx)

proc addCount(a, b: int, ctx: string): int {.raises: [BuyanError].} =
  ## Adds nonnegative counts and rejects integer overflow.
  if b < 0 or a < 0:
    fail("Negative count in " & ctx)
  if b > 0 and a > int.high - b:
    fail("Integer overflow in " & ctx)
  a + b

proc identOf(policy: PolicyRef): string {.raises: [].} =
  ## Formats a pinned policy identity.
  policy.policyName & "|" & $policy.version & "|" & policy.policyVersionId

proc participantIdent(node: JsonNode, ctx: string): string {.
    raises: [BuyanError].} =
  ## Reads policy_name, version, and policy_version_id as one identity.
  reqNonemptyStr(node, "policy_name", ctx) & "|" &
    $reqInt(node, "version", ctx) & "|" &
    reqNonemptyStr(node, "policy_version_id", ctx)

proc parsePolicy(node: JsonNode, ctx: string, seatsRequired: bool): PolicyRef {.
    raises: [BuyanError].} =
  ## Parses one pinned policy identity from the plan.
  if node.kind != JObject:
    fail("Policy identity must be an object in " & ctx)
  result.policyName = reqNonemptyStr(node, "policy_name", ctx)
  result.version = reqInt(node, "version", ctx)
  result.policyVersionId = reqNonemptyStr(node, "policy_version_id", ctx)
  if seatsRequired:
    result.seats = reqPosInt(node, "seats", ctx)
  else:
    result.seats = 1

proc registerVersionId(
  byId: var Table[string, string], policy: PolicyRef, ctx: string
) {.raises: [BuyanError].} =
  ## Rejects one policy_version_id bound to two identity strings.
  let ident = identOf(policy)
  if byId.hasKey(policy.policyVersionId):
    let previous = byId.getOrDefault(policy.policyVersionId)
    if previous != ident:
      fail("policy_version_id " & policy.policyVersionId &
        " maps to multiple identities in " & ctx)
  else:
    byId[policy.policyVersionId] = ident

proc opponentCounts(plan: Plan): CountTable[string] {.raises: [BuyanError].} =
  ## Builds the pinned opponent identity multiset.
  if plan.opponents.len == 0:
    fail("Plan opponents must not be empty")
  var total = 0
  for opponent in plan.opponents:
    let key = identOf(opponent)
    if key == identOf(plan.baseline) or key == identOf(plan.candidate):
      fail("Opponent identity collides with comparison seat")
    result.inc(key, opponent.seats)
    total = addCount(total, opponent.seats, "opponent seats")
  if total != ExpectedOpponentSeats:
    fail("Plan must pin exactly six opponent seats, got " & $total)

proc parsePlan*(node: JsonNode): Plan {.raises: [BuyanError].} =
  ## Parses and pins the comparison plan. Membership is never inferred.
  if node.isNil or node.kind != JObject:
    fail("Plan must be a JSON object")
  result.source = reqStr(node, "source", "plan")
  if result.source != SourceName:
    fail("Plan source must be " & SourceName)
  result.experiment = reqNonemptyStr(node, "experiment", "plan")
  result.coworldId = reqNonemptyStr(node, "coworld_id", "plan")
  result.coworldVersion = reqNonemptyStr(node, "coworld_version", "plan")
  result.baseline = parsePolicy(
    reqObj(node, "baseline", "plan"), "plan.baseline", false)
  result.candidate = parsePolicy(
    reqObj(node, "candidate", "plan"), "plan.candidate", false)
  if result.baseline.policyVersionId == result.candidate.policyVersionId:
    fail("Baseline and candidate policy_version_id must differ")
  if identOf(result.baseline) == identOf(result.candidate):
    fail("Baseline and candidate identities must differ")
  var opponentNodes = reqArr(node, "opponents", "plan")
  for opponent in opponentNodes:
    result.opponents.add parsePolicy(opponent, "plan.opponents", true)
  discard opponentCounts(result)
  var byId = initTable[string, string]()
  registerVersionId(byId, result.baseline, "plan")
  registerVersionId(byId, result.candidate, "plan")
  for opponent in result.opponents:
    registerVersionId(byId, opponent, "plan")
  let requests = reqArr(node, "requests", "plan")
  if requests.len == 0:
    fail("Plan requests must not be empty")
  var
    xpIds = initHashSet[string]()
    files = initHashSet[string]()
  for request in requests:
    if request.kind != JObject:
      fail("Plan request must be an object")
    var row: PlanRequest
    row.xpId = reqNonemptyStr(request, "xp_id", "plan.requests")
    row.episodesFile = reqNonemptyStr(request, "episodes_file", "plan.requests")
    row.episodeCount = reqPosInt(request, "episode_count", "plan.requests")
    if row.xpId in xpIds:
      fail("Repeated request xp_id " & row.xpId)
    if row.episodesFile in files:
      fail("Repeated request episodes_file " & row.episodesFile)
    xpIds.incl(row.xpId)
    files.incl(row.episodesFile)
    result.requests.add(row)
  let syn = child(node, "synthetic")
  if not syn.isNil and syn.kind != JNull:
    result.synthetic = reqBool(node, "synthetic", "plan")

proc samePath(planned, given: string): bool {.raises: [].} =
  ## Matches a plan file path to a CLI path by exact or absolute path.
  if planned == given:
    return true
  if planned.len == 0 or given.len == 0:
    return false
  try:
    result = expandFilename(planned) == expandFilename(given)
  except CatchableError:
    result = false

proc assignDocs(
  plan: Plan,
  docs: seq[tuple[path: string, node: JsonNode]]
): seq[tuple[path: string, node: JsonNode]] {.raises: [BuyanError].} =
  ## Maps each plan request to exactly one episode document.
  if docs.len != plan.requests.len:
    fail("Episode file count must equal plan request count")
  var used = newSeq[bool](docs.len)
  for request in plan.requests:
    var found = -1
    for i, doc in docs:
      if samePath(request.episodesFile, doc.path):
        if found >= 0:
          fail("Repeated file match for " & request.episodesFile)
        found = i
    if found < 0:
      fail("Missing episodes file for request " & request.xpId &
        ": " & request.episodesFile)
    if used[found]:
      fail("Repeated input file " & docs[found].path)
    used[found] = true
    result.add(docs[found])
  for i, flag in used:
    if not flag:
      fail("Extra input file not in plan: " & docs[i].path)

proc optionalStrMatch(
  node: JsonNode, key, expected, ctx: string
) {.raises: [BuyanError].} =
  ## If a field exists, it must match the expected plan value.
  let value = child(node, key)
  if value.isNil or value.kind == JNull:
    return
  if value.kind != JString:
    fail("Field " & key & " must be a string in " & ctx)
  if value.getStr != expected:
    fail(ctx & " " & key & " does not match plan")

proc extractEpisodes(
  node: JsonNode, request: PlanRequest, plan: Plan, path: string
): seq[JsonNode] {.raises: [BuyanError].} =
  ## Reads a saved xp-request episodes array or wrapper object.
  case node.kind
  of JArray:
    result = node.getElems
  of JObject:
    let wrapId = child(node, "id")
    if not wrapId.isNil and wrapId.kind != JNull:
      if wrapId.kind != JString:
        fail("Field id must be a string in " & path)
      if wrapId.getStr != request.xpId:
        fail("Wrapper id " & wrapId.getStr & " does not match plan xp_id " &
          request.xpId)
    optionalStrMatch(node, "source", plan.source, path)
    optionalStrMatch(node, "experiment", plan.experiment, path)
    optionalStrMatch(node, "coworld_id", plan.coworldId, path)
    optionalStrMatch(node, "coworld_version", plan.coworldVersion, path)
    optionalStrMatch(node, "xp_id", request.xpId, path)
    let episodesField = child(node, "episodes")
    let entriesField = child(node, "entries")
    if not episodesField.isNil and not entriesField.isNil:
      fail("Episode file " & path & " has both episodes and entries")
    elif not episodesField.isNil:
      if episodesField.kind != JArray:
        fail("episodes must be an array in " & path)
      result = episodesField.getElems
    elif not entriesField.isNil:
      if entriesField.kind != JArray:
        fail("entries must be an array in " & path)
      result = entriesField.getElems
    else:
      fail("Episode file " & path & " is missing episodes or entries")
  else:
    fail("Episode file " & path & " must be a JSON array or object")
  if result.len != request.episodeCount:
    fail("Episode file " & path & " has " & $result.len &
      " entries, plan episode_count is " & $request.episodeCount)

proc inspectEpisode(
  plan: Plan, expected: CountTable[string], xpId: string, node: JsonNode
): LoadedEpisode {.raises: [BuyanError].} =
  ## Validates membership even for failed episodes. Unexpected identity is fatal.
  if node.kind != JObject:
    fail("Episode must be an object")
  result.id = reqNonemptyStr(node, "id", "episode")
  result.xpId = xpId
  result.jobIndex = reqInt(node, "job_index", result.id)
  result.status = reqStr(node, "status", result.id)
  result.node = node
  result.baselinePos = -1
  result.candidatePos = -1
  optionalStrMatch(node, "source", plan.source, result.id)
  optionalStrMatch(node, "experiment", plan.experiment, result.id)
  optionalStrMatch(node, "xp_id", xpId, result.id)
  if reqNonemptyStr(node, "coworld_id", result.id) != plan.coworldId:
    fail("Episode " & result.id & " coworld_id does not match plan")
  if reqNonemptyStr(node, "coworld_version", result.id) != plan.coworldVersion:
    fail("Episode " & result.id & " coworld_version does not match plan")
  let participants = reqArr(node, "participants", result.id)
  var
    seenPos = initHashSet[int]()
    gotOpp = initCountTable[string]()
    nBase = 0
    nCand = 0
  for participant in participants:
    if participant.kind != JObject:
      fail("Participant must be an object in " & result.id)
    let pos = reqInt(participant, "position", result.id)
    if pos < 0:
      fail("Negative position in " & result.id)
    if pos in seenPos:
      fail("Duplicate position " & $pos & " in episode " & result.id)
    seenPos.incl(pos)
    let key = participantIdent(participant, result.id)
    if key == identOf(plan.baseline):
      inc nBase
      result.baselinePos = pos
    elif key == identOf(plan.candidate):
      inc nCand
      result.candidatePos = pos
    elif key in expected:
      gotOpp.inc(key)
    else:
      fail("Unexpected identity in episode " & result.id & ": " & key)
  if nBase > 1:
    fail("Episode " & result.id & " has more than one baseline seat")
  if nCand > 1:
    fail("Episode " & result.id & " has more than one candidate seat")
  if gotOpp != expected:
    fail("Opponent identities or counts mismatch in episode " & result.id)

proc isCompleted(status: string): bool {.raises: [].} =
  ## Hosted completed terminal status.
  status == "completed"

proc isFailed(status: string): bool {.raises: [].} =
  ## Hosted failed terminal status.
  status == "failed"

proc isCancelled(status: string): bool {.raises: [].} =
  ## Hosted cancelled terminal status.
  status == "cancelled"

proc isUnresolved(status: string): bool {.raises: [].} =
  ## Pending, running, submitted, or any other nonterminal status.
  not isCompleted(status) and not isFailed(status) and not isCancelled(status)

proc parseActivations*(
  node: JsonNode, plan: Plan
): Table[string, Activation] {.raises: [BuyanError].} =
  ## Parses activation evidence. Scores in this file are ignored.
  if node.isNil or node.kind != JObject:
    fail("Activation document must be a JSON object")
  if reqStr(node, "source", "activations") != plan.source:
    fail("Activation source does not match plan")
  if reqNonemptyStr(node, "experiment", "activations") != plan.experiment:
    fail("Activation experiment does not match plan")
  if reqNonemptyStr(node, "coworld_id", "activations") != plan.coworldId:
    fail("Activation coworld_id does not match plan")
  if reqNonemptyStr(node, "coworld_version", "activations") != plan.coworldVersion:
    fail("Activation coworld_version does not match plan")
  if reqNonemptyStr(node, "candidate_policy_version_id", "activations") !=
      plan.candidate.policyVersionId:
    fail("Activation candidate_policy_version_id does not match plan")
  let rows = reqArr(node, "episodes", "activations")
  for row in rows:
    if row.kind != JObject:
      fail("Activation episode must be an object")
    var item: Activation
    item.xpId = reqNonemptyStr(row, "xp_id", "activation")
    item.episodeId = reqNonemptyStr(row, "episode_id", "activation")
    item.candidatePosition = reqInt(row, "candidate_position", item.episodeId)
    if item.candidatePosition < 0:
      fail("Negative candidate_position in activation " & item.episodeId)
    item.verified = reqBool(row, "verified", item.episodeId)
    item.triggerCount = reqNonnegInt(row, "trigger_count", item.episodeId)
    item.logPath = reqStr(row, "log_path", item.episodeId)
    item.metric = reqStr(row, "metric", item.episodeId)
    if item.episodeId in result:
      fail("Duplicate activation episode_id " & item.episodeId)
    result[item.episodeId] = item

proc readScore(
  node: JsonNode, pos: int, episodeId: string
): tuple[ok: bool, value: float] {.raises: [BuyanError].} =
  ## Reads one finite participant score. Missing or nonfinite is not ok.
  let scores = child(node, "participant_scores")
  if scores.isNil or scores.kind == JNull:
    return (false, 0.0)
  if scores.kind != JArray:
    fail("participant_scores must be an array in " & episodeId)
  var found = 0
  var sawMissing = false
  var value = 0.0
  var ok = false
  for entry in scores:
    if entry.kind != JObject:
      fail("participant_scores entry must be an object in " & episodeId)
    let position = reqInt(entry, "position", episodeId)
    if position != pos:
      continue
    inc found
    if found > 1:
      fail("Duplicate score position " & $pos & " in " & episodeId)
    let raw = child(entry, "score")
    if raw.isNil or raw.kind == JNull:
      sawMissing = true
      continue
    var parsed: float
    case raw.kind
    of JInt:
      parsed = float(raw.getInt)
    of JFloat:
      parsed = raw.getFloat
    else:
      fail("score must be numeric in episode " & episodeId)
    if not isFiniteNumber(parsed):
      sawMissing = true
      continue
    ok = true
    value = parsed
  if found == 0 or sawMissing or not ok:
    result = (false, 0.0)
  else:
    result = (true, value)

proc signTestP*(wins, losses: int): float {.raises: [BuyanError].} =
  ## Exact two-sided paired sign-test p-value. Ties are omitted from n.
  if wins < 0 or losses < 0:
    fail("Sign-test counts must be nonnegative")
  let n = addCount(wins, losses, "sign-test n")
  if n > MaxExactSignN:
    fail("Sign-test exact n must be <= 300")
  if n == 0:
    return 1.0
  let k = min(wins, losses)
  var
    term = pow(2.0, -float(n))
    total = term
  reqFinite(term, "sign-test term")
  for i in 0 ..< k:
    term = term * float(n - i) / float(i + 1)
    total = addFinite(total, term, "sign-test sum")
  result = min(1.0, 2.0 * total)
  reqFinite(result, "sign-test p-value")

proc decideGate*(
  n, wins, losses, unresolved: int;
  meanDiff, p: float
): string {.raises: [BuyanError].} =
  ## Fixed-look gate. Unresolved registered episodes block support.
  if n < 0 or wins < 0 or losses < 0 or unresolved < 0:
    fail("Gate counts must be nonnegative")
  let nonTies = addCount(wins, losses, "gate non-ties")
  if n < nonTies:
    fail("n must be >= wins+losses")
  reqFinite(meanDiff, "mean diff")
  if unresolved > 0:
    return "awaiting_completion"
  if n < 10:
    return "insufficient_data"
  if n > MaxExactSignN:
    return "off_schedule"
  var onLook = false
  for look in LookSizes:
    if n == look:
      onLook = true
  if not onLook:
    return "off_schedule"
  let expected = signTestP(wins, losses)
  if p != expected:
    fail("Gate p-value does not match signTestP")
  let
    positive = meanDiff > 0.0 and wins > losses
    significant = p <= PerLookAlpha
  if significant and positive:
    return "support"
  if significant and (meanDiff < 0.0 or losses > wins):
    return "negative"
  "inconclusive"

proc loadJsonFile*(path: string): JsonNode {.raises: [BuyanError].} =
  ## Reads one JSON file and maps I/O or parse errors to BuyanError.
  try:
    result = parseFile(path)
  except IOError as err:
    wrap("I/O error reading " & path, err)
  except JsonParsingError as err:
    wrap("JSON parse error in " & path, err)
  except CatchableError as err:
    wrap("Failed to read JSON " & path, err)

proc currentDir(): string {.raises: [BuyanError].} =
  ## Maps getCurrentDir OSError to BuyanError.
  try:
    result = getCurrentDir()
  except OSError as err:
    wrap("Cannot read current directory", err)

proc resolvePath(path, baseDir: string): string {.raises: [BuyanError].} =
  ## Resolves a relative path against baseDir to an absolute path.
  if path.len == 0:
    fail("Empty path")
  try:
    if isAbsolute(path):
      result = expandFilename(path)
    elif baseDir.len == 0:
      result = expandFilename(path)
    else:
      result = expandFilename(baseDir / path)
  except OSError as err:
    wrap("Cannot resolve path " & path, err)
  except CatchableError as err:
    wrap("Cannot resolve path " & path, err)

proc compare*(
  planNode, activationNode: JsonNode,
  episodeDocs: seq[tuple[path: string, node: JsonNode]]
): JsonNode {.raises: [BuyanError].} =
  ## Compares pinned baseline vs candidate inside the same hosted episodes.
  let
    plan = parsePlan(planNode)
    expected = opponentCounts(plan)
    matched = assignDocs(plan, episodeDocs)
    activations = parseActivations(activationNode, plan)
  var
    loaded: seq[LoadedEpisode]
    seenIds = initHashSet[string]()
    seenJobs = initTable[string, HashSet[int]]()
  for i, request in plan.requests:
    let nodes = extractEpisodes(
      matched[i].node, request, plan, matched[i].path)
    var jobs = seenJobs.mgetOrPut(request.xpId, initHashSet[int]())
    var batch: seq[LoadedEpisode]
    for node in nodes:
      let episode = inspectEpisode(plan, expected, request.xpId, node)
      if episode.id in seenIds:
        fail("Duplicate episode id " & episode.id)
      seenIds.incl(episode.id)
      if episode.jobIndex in jobs:
        fail("Duplicate job_index " & $episode.jobIndex &
          " in request " & request.xpId)
      jobs.incl(episode.jobIndex)
      batch.add(episode)
    seenJobs[request.xpId] = jobs
    batch.sort do (a, b: LoadedEpisode) -> int:
      cmp(a.jobIndex, b.jobIndex)
    loaded.add(batch)
  var byId = initTable[string, LoadedEpisode]()
  for episode in loaded:
    byId[episode.id] = episode
  for episodeId, item in activations:
    if episodeId notin byId:
      fail("Unknown activation episode_id " & episodeId)
    let foundEp = byId.getOrDefault(episodeId)
    if item.xpId != foundEp.xpId:
      fail("Activation xp_id does not match episode " & episodeId)
    if foundEp.candidatePos >= 0 and
        item.candidatePosition != foundEp.candidatePos:
      fail("Activation candidate_position does not match episode " & episodeId)
  var
    pairs: seq[PairRow]
    failed, cancelled, pending = 0
    missingParticipant, missingScore = 0
    missingEvidence, unverified, notTriggered = 0
    unresolvedEpisodes = 0
    unresolvedByRequest = initCountTable[string]()
  for episode in loaded:
    if isUnresolved(episode.status):
      inc unresolvedEpisodes
      unresolvedByRequest.inc(episode.xpId)
    if episode.baselinePos < 0 or episode.candidatePos < 0:
      inc missingParticipant
      continue
    if isFailed(episode.status):
      inc failed
      continue
    if isCancelled(episode.status):
      inc cancelled
      continue
    if isUnresolved(episode.status):
      inc pending
      continue
    if not isCompleted(episode.status):
      inc pending
      continue
    let
      baseScore = readScore(
        episode.node, episode.baselinePos, episode.id)
      candScore = readScore(
        episode.node, episode.candidatePos, episode.id)
    if not baseScore.ok or not candScore.ok:
      inc missingScore
      continue
    if episode.id notin activations:
      inc missingEvidence
      continue
    let evidence = activations.getOrDefault(episode.id)
    if not evidence.verified or evidence.logPath.len == 0 or
        evidence.metric.len == 0:
      inc unverified
      continue
    if evidence.triggerCount <= 0:
      inc notTriggered
      continue
    var row: PairRow
    row.id = episode.id
    row.xpId = episode.xpId
    row.jobIndex = episode.jobIndex
    row.baseline = baseScore.value
    row.candidate = candScore.value
    row.diff = addFinite(
      row.candidate, -row.baseline, "paired difference " & episode.id)
    row.triggers = evidence.triggerCount
    pairs.add(row)
  var
    wins, losses, ties = 0
    baseSum, candSum, diffSum = 0.0
    activationsSum = 0
  for row in pairs:
    baseSum = addFinite(baseSum, row.baseline, "baseline sum")
    candSum = addFinite(candSum, row.candidate, "candidate sum")
    diffSum = addFinite(diffSum, row.diff, "difference sum")
    activationsSum = addCount(
      activationsSum, row.triggers, "total activations")
    if row.diff > 0.0:
      inc wins
    elif row.diff < 0.0:
      inc losses
    else:
      inc ties
  let
    n = pairs.len
    nonTies = addCount(wins, losses, "non-ties")
  var
    baseMean = 0.0
    candMean = 0.0
    meanDiff = 0.0
    p = 1.0
    pNode = newJNull()
  if n > 0:
    baseMean = baseSum / float(n)
    candMean = candSum / float(n)
    meanDiff = diffSum / float(n)
    reqFinite(baseMean, "baseline mean")
    reqFinite(candMean, "candidate mean")
    reqFinite(meanDiff, "paired mean diff")
  if nonTies <= MaxExactSignN:
    p = signTestP(wins, losses)
    pNode = newJFloat(p)
  let status = decideGate(
    n, wins, losses, unresolvedEpisodes, meanDiff, p)
  var episodeJson = newJArray()
  for row in pairs:
    episodeJson.add(%*{
      "episode_id": row.id,
      "xp_id": row.xpId,
      "job_index": row.jobIndex,
      "baseline_score": row.baseline,
      "candidate_score": row.candidate,
      "diff": row.diff,
      "trigger_count": row.triggers
    })
  result = %*{
    "source": plan.source,
    "experiment": plan.experiment,
    "coworld_id": plan.coworldId,
    "coworld_version": plan.coworldVersion,
    "baseline": {
      "policy_name": plan.baseline.policyName,
      "version": plan.baseline.version,
      "policy_version_id": plan.baseline.policyVersionId
    },
    "candidate": {
      "policy_name": plan.candidate.policyName,
      "version": plan.candidate.version,
      "policy_version_id": plan.candidate.policyVersionId
    },
    "synthetic": plan.synthetic,
    "score_claim": "none",
    "n": n,
    "wins": wins,
    "losses": losses,
    "ties": ties,
    "non_ties": nonTies,
    "sign_test_p": pNode,
    "total_activations": activationsSum,
    "unresolved_episodes": unresolvedEpisodes,
    "unresolved_requests": unresolvedByRequest.len,
    "episodes": episodeJson,
    "exclusions": {
      "failed": failed,
      "cancelled": cancelled,
      "pending": pending,
      "missing_participant": missingParticipant,
      "missing_score": missingScore,
      "missing_evidence": missingEvidence,
      "unverified_evidence": unverified,
      "not_triggered": notTriggered
    },
    "dashboard_required": true,
    "dashboard_note": DashboardNote,
    "authenticity": AuthenticityNote,
    "limitation": LimitationNote,
    "gates": {
      "family_alpha": FamilyAlpha,
      "hypotheses": HypothesisCount,
      "looks": [10, 30, 100, 300],
      "per_look_alpha": PerLookAlpha,
      "status": status
    }
  }
  if n == 0:
    result["baseline_mean"] = newJNull()
    result["candidate_mean"] = newJNull()
    result["paired_mean_diff"] = newJNull()
  else:
    result["baseline_mean"] = newJFloat(baseMean)
    result["candidate_mean"] = newJFloat(candMean)
    result["paired_mean_diff"] = newJFloat(meanDiff)

proc compareFiles*(
  planPath, activationPath: string, episodePaths: seq[string]
): JsonNode {.raises: [BuyanError].} =
  ## Loads plan, activations, and episode files then compares them.
  if episodePaths.len == 0:
    fail("At least one episodes file is required")
  var seen = initHashSet[string]()
  var docs: seq[tuple[path: string, node: JsonNode]]
  for path in episodePaths:
    if path.len == 0:
      fail("Empty episodes file path")
    let resolved = resolvePath(path, currentDir())
    if resolved in seen:
      fail("Repeated input file " & path)
    seen.incl(resolved)
    docs.add((resolved, loadJsonFile(path)))
  let planNode = loadJsonFile(planPath)
  let planDir = parentDir(resolvePath(planPath, currentDir()))
  let requests = child(planNode, "requests")
  if not requests.isNil and requests.kind == JArray:
    for request in requests:
      if request.kind != JObject:
        continue
      let raw = child(request, "episodes_file")
      if raw.isNil or raw.kind != JString:
        continue
      request["episodes_file"] = %resolvePath(raw.getStr, planDir)
  compare(planNode, loadJsonFile(activationPath), docs)
