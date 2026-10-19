import
  std/[algorithm, json, os, sets, strformat],
  zippy,
  sim, match, replays

type
  AwmError = object of CatchableError
  Cohort = object
    coworld, sourceVersion, policy, player: string
    policyVersion, players: int
    opponents, identities: seq[string]
  Episode = object
    id, job: string
    seat, maximumTicks: int
    won: bool
  ClassCount = object
    games, wins: int

proc fail(message: string) {.noreturn.} =
  ## Raises a game-specific diagnostic at an invalid input boundary.
  raise newException(AwmError, message)

proc readText(path: string): string =
  ## Reads a saved input while preserving an explicit diagnostic.
  try:
    result = readFile(path)
  except IOError as error:
    fail("Cannot read " & path & ": " & error.msg)

proc readJson(path: string): JsonNode =
  ## Parses hosted metadata with a game-specific exception.
  try:
    result = parseJson(readText(path))
  except JsonParsingError as error:
    fail("Invalid hosted JSON: " & error.msg)

proc field(node: JsonNode, name: string, kind: JsonNodeKind): JsonNode =
  ## Requires a field of the stated kind instead of applying defaults.
  if node.kind != JObject or not node.hasKey(name) or
    node[name].kind != kind:
      fail("Hosted metadata requires " & $kind & " field " & name)
  node[name]

proc text(node: JsonNode, name: string): string =
  ## Reads a required string field.
  node.field(name, JString).getStr

proc number(node: JsonNode, name: string): int =
  ## Reads a required integer field.
  node.field(name, JInt).getInt

proc score(node: JsonNode): float =
  ## Requires binary AWM hosted scores for actual last-survivor wins.
  if node.kind != JObject or not node.hasKey("score") or
    node["score"].kind notin {JInt, JFloat}:
      fail("Hosted score requires a numeric score field")
  result = node["score"].getFloat
  if result != 0.0 and result != 1.0:
    fail("AWM last-survivor score must be zero or one")

proc bindEpisode(
    node: JsonNode,
    request: JsonNode,
    cohort: var Cohort
): Episode =
  ## Binds exact seats and hosted scores to one consistent policy cohort.
  result.id = node.text("id")
  result.job = node.text("job_id")
  if result.job.len == 0 or result.job.extractFilename != result.job or
    result.job in [".", ".."]:
      fail("Invalid replay job basename for " & result.id)
  let
    coworld = node.text("coworld_id")
    sourceVersion = node.text("coworld_version")
    participants = node.field("participants", JArray)
    policyIds = node.field("policy_version_ids", JArray)
    count = participants.len
  if coworld != request.text("coworld_id") or
    sourceVersion != request.text("coworld_version"):
      fail("Episode differs from request Coworld/source version")
  if count notin 2 .. MaxPlayers or policyIds.len != count:
    fail("AWM participant and policy counts must agree")
  var
    occupied = newSeq[bool](count)
    versions = newSeq[string](count)
    positions: seq[int]
    candidate: JsonNode
    currentOpponents: seq[string]
    currentIdentities: seq[string]
    seenVersions: HashSet[string]
  for participant in participants:
    let
      seat = participant.number("position")
      version = participant.text("policy_version_id")
      player = participant.text("player_id")
      policyName = participant.text("policy_name")
      policyVersion = participant.number("version")
    if seat notin 0 ..< count or occupied[seat]:
      fail("Participant seats must be unique and contiguous")
    if version.len == 0 or version in seenVersions:
      fail("Policy version IDs must be nonempty and unique")
    if player.len == 0 or policyVersion <= 0:
      fail("Participant player IDs and versions must be explicit")
    seenVersions.incl version
    occupied[seat] = true
    versions[seat] = version
    if policyIds[seat].kind != JString or
      policyIds[seat].getStr != version:
        fail("Participant version differs from ordered policy IDs")
    if policyName == "radogost":
      positions.add seat
      candidate = participant
    else:
      currentOpponents.add version
      currentIdentities.add version & ":" & player & ":" & policyName &
        ":" & $policyVersion
  if positions.len != 1:
    fail("Expected exactly one participant named radogost")
  result.seat = positions[0]
  currentOpponents.sort()
  currentIdentities.sort()
  let
    policy = candidate.text("policy_version_id")
    player = candidate.text("player_id")
    policyVersion = candidate.number("version")
  if cohort.policy.len == 0:
    cohort = Cohort(
      coworld: coworld,
      sourceVersion: sourceVersion,
      policy: policy,
      player: player,
      policyVersion: policyVersion,
      players: count,
      opponents: currentOpponents,
      identities: currentIdentities
    )
  if cohort.coworld != coworld or cohort.sourceVersion != sourceVersion or
    cohort.policy != policy or cohort.player != player or
    cohort.policyVersion != policyVersion or cohort.players != count or
    cohort.opponents != currentOpponents or
    cohort.identities != currentIdentities:
      fail("Cannot combine different policy, source, player or opponents")
  let
    participantScores = node.field("participant_scores", JArray)
    policyScores = node.field("scores", JArray)
  if participantScores.len != count or policyScores.len != count:
    fail("Both hosted score arrays must cover every participant")
  var
    scores = newSeq[float](count)
    scored = newSeq[bool](count)
    policyScored: HashSet[string]
    totalWins = 0
  for item in participantScores:
    let seat = item.number("position")
    if seat notin 0 ..< count or scored[seat]:
      fail("Hosted score positions must be unique and complete")
    scored[seat] = true
    scores[seat] = item.score
    if scores[seat] == 1.0:
      inc totalWins
  if totalWins > 1:
    fail("AWM hosted scores name more than one last survivor")
  for item in policyScores:
    let version = item.text("policy_version_id")
    if version notin seenVersions or version in policyScored:
      fail("Hosted policy scores must match unique participants")
    policyScored.incl version
    let seat = versions.find(version)
    if item.score != scores[seat]:
      fail("Hosted policy and participant scores disagree")
  result.won = scores[result.seat] == 1.0
  let config = node.field("game_config", JObject)
  if config.field("players", JArray).len != count:
    fail("Hosted game config player count differs from participants")
  result.maximumTicks = config.number("max_ticks")

proc replayClass(path: string, episode: Episode, players: int): HeroClass =
  ## Verifies the public replay, then reads the mapped seat's header class.
  var bytes = readText(path)
  if bytes.len > 2 and bytes[0] == '\x1f' and bytes[1] == '\x8b':
    try:
      bytes = uncompress(bytes, dfGzip)
    except ZippyError as error:
      fail("Invalid compressed replay: " & error.msg)
  var data: ReplayData
  try:
    data = decodeReplayFile(ReplayGame, ReplayGameVersion, bytes, ReplayData)
    data.validate()
  except ReplayError as error:
    fail("Invalid AWM replay: " & error.msg)
  if data.header.setup.classes.len != players or
    data.config.maxTicks != episode.maximumTicks:
      fail("Replay setup differs from hosted job " & episode.job)
  var
    game = newGame(data.header.setup.heroClasses, data.header.setup.seed)
    check: ReplayHashCheck
    tick = 0'u32
  for action in data.actions:
    if not game.applyAction(action):
      fail("Replay action refused for " & episode.job & " at " &
        $action.tick)
    discard game.takeVisualEvents()
    tick = action.tick
    data.hashes.checkReplayHash(tick, game.stateHash, check)
  try:
    check.requireReplayComplete(tick, data.hashes.len)
  except ReplayError as error:
    fail("Replay verification failed for " & episode.job & ": " & error.msg)
  var living: seq[int]
  for seat in 0 ..< players:
    if not game.players[seat].dead:
      living.add seat
  let actualWin = game.gameOver and game.winner == episode.seat and
    living == @[episode.seat]
  if actualWin != episode.won:
    fail("Hosted last-survivor score disagrees with replay " & episode.job)
  data.header.setup.heroClasses[episode.seat]

proc main() =
  ## Reports hosted class counts with explicit replay coverage and identity.
  if paramCount() notin 2 .. 3:
    fail("Usage: classes STATUS_JSON REPLAYDIR [SUMMARY_JSON]")
  let
    request = readJson(paramStr(1))
    episodes = request.field("episodes", JArray)
    replayDirectory = paramStr(2)
  var
    cohort: Cohort
    counts: array[HeroClass, ClassCount]
    seenIds, seenJobs: HashSet[string]
    missing = newJArray()
    classified = newJArray()
    games, wins, failed, unfinished, covered, coveredWins = 0
  for node in episodes:
    let
      id = node.text("id")
      status = node.text("status")
    if id in seenIds:
      fail("Duplicate hosted episode " & id)
    seenIds.incl id
    if status == "failed":
      inc failed
      continue
    if status != "completed":
      inc unfinished
      continue
    let episode = bindEpisode(node, request, cohort)
    if episode.job in seenJobs:
      fail("Duplicate replay job " & episode.job)
    seenJobs.incl episode.job
    inc games
    if episode.won:
      inc wins
    let path = replayDirectory / (episode.job & ".replay")
    if not fileExists(path):
      missing.add %*{"id": episode.id, "job_id": episode.job}
      continue
    let hero = replayClass(path, episode, cohort.players)
    inc counts[hero].games
    inc covered
    if episode.won:
      inc counts[hero].wins
      inc coveredWins
    classified.add %*{
      "id": episode.id,
      "job_id": episode.job,
      "position": episode.seat,
      "hero_class": $hero,
      "hosted_win": episode.won
    }
  if request.number("completed_count") != games or
    request.number("failed_count") != failed or
    request.number("episode_count") != episodes.len:
      fail("Request episode counts disagree with saved episode metadata")
  var classes = newJArray()
  echo "Class     Games  Wins  Hosted win rate"
  for hero in HeroClass:
    let
      count = counts[hero]
      rate =
        if count.games > 0:
          count.wins.float / count.games.float
        else:
          0.0
    classes.add %*{
      "hero_class": $hero,
      "games": count.games,
      "wins": count.wins,
      "win_rate": rate
    }
    if count.games > 0:
      echo &"{($hero):<9} {count.games:>5} {count.wins:>5} " &
        &"{rate * 100:>7.1f}%"
    else:
      echo &"{($hero):<9} {count.games:>5} {count.wins:>5} " &
        "     n/a"
  let complete = missing.len == 0 and unfinished == 0
  echo "Hosted total: ", wins, "/", games,
    "; class coverage: ", covered, "/", games,
    "; covered wins: ", coveredWins,
    "; missing replays: ", missing.len,
    "; failed: ", failed, "; unfinished: ", unfinished
  echo "Policy: radogost:v", cohort.policyVersion, " ", cohort.policy
  echo "Coworld: ", cohort.coworld, " source version ", cohort.sourceVersion
  if not complete:
    echo "INCOMPLETE: class rows cover only verified available replays."
  if paramCount() == 3:
    let summary = %*{
      "id": request.text("id"),
      "status": request.text("status"),
      "coworld_id": cohort.coworld,
      "coworld_version": cohort.sourceVersion,
      "replay_game_version": ReplayGameVersion,
      "policy_version_id": cohort.policy,
      "policy_version": cohort.policyVersion,
      "player_id": cohort.player,
      "opponents": cohort.opponents,
      "opponent_identities": cohort.identities,
      "players": cohort.players,
      "games": games,
      "wins": wins,
      "classified_games": covered,
      "classified_wins": coveredWins,
      "coverage_complete": complete,
      "failed": failed,
      "unfinished": unfinished,
      "missing_replays": missing,
      "classes": classes,
      "episodes": classified
    }
    try:
      writeFile(paramStr(3), summary.pretty & "\n")
    except IOError as error:
      fail("Cannot save class summary: " & error.msg)

main()
