import
  std/[json, math, os, sets, strformat, strutils],
  crunchy

const
  SeatCount = 5
  SourceLimit = 256 * 1024

type
  AwmError = object of CatchableError
  Episode = object
    seed, index, winner: int
    classes, seating: seq[int]
    won: bool
  Batch = object
    sourceHash: string
    opponents: seq[string]
    episodes: seq[Episode]
    attribution: JsonNode

proc readJson(path: string): JsonNode =
  ## Reads saved artifacts with explicit AWM boundary errors.
  try:
    result = parseJson(readFile(path))
  except IOError, JsonParsingError:
    raise newException(AwmError,
      "Cannot read fast artifact " & path & ": " & getCurrentExceptionMsg())
  if result.kind != JObject:
    raise newException(AwmError, "Fast artifact must be an object: " & path)

proc integer(node: JsonNode, key: string): int =
  ## Requires integer metadata without coercing malformed values.
  if not node.hasKey(key) or node[key].kind != JInt:
    raise newException(AwmError, "Missing integer field: " & key)
  node[key].getInt

proc text(node: JsonNode, key: string): string =
  ## Requires nonempty text for source and response attribution.
  if not node.hasKey(key) or node[key].kind != JString or
    node[key].getStr.len == 0:
      raise newException(AwmError, "Missing text field: " & key)
  node[key].getStr

proc boolean(node: JsonNode, key: string): bool =
  ## Requires explicit flags rather than defaulting missing diagnostics.
  if not node.hasKey(key) or node[key].kind != JBool:
    raise newException(AwmError, "Missing boolean field: " & key)
  node[key].getBool

proc items(node: JsonNode, key: string): JsonNode =
  ## Requires an array before indexing saved batch metadata.
  if not node.hasKey(key) or node[key].kind != JArray:
    raise newException(AwmError, "Missing array field: " & key)
  node[key]

proc integers(node: JsonNode, key: string): seq[int] =
  ## Reads integer arrays without silent element coercion.
  for item in node.items(key):
    if item.kind != JInt:
      raise newException(AwmError, "Invalid integer array: " & key)
    result.add item.getInt

proc objectField(node: JsonNode, key: string): JsonNode =
  ## Requires a policy object at the request boundary.
  if not node.hasKey(key) or node[key].kind != JObject:
    raise newException(AwmError, "Missing object field: " & key)
  node[key]

proc attribution(
  directory: string, meta, response: JsonNode
): JsonNode =
  ## Retains known endpoint fields without inferring absent service URLs.
  result = %*{
    "directory": absolutePath(directory),
    "request_id": response.text("request_id"),
    "endpoint_attribution": "directory-only",
    "metadata": newJObject()
  }
  for key in ["endpoint", "service_url", "base_url", "endpoint_url"]:
    for node in [meta, response]:
      if node.hasKey(key):
        let value = node.text(key)
        if result["metadata"].hasKey(key) and
          result["metadata"][key].getStr != value:
            raise newException(AwmError, "Conflicting endpoint metadata")
        result["metadata"][key] = %value
        result["endpoint_attribution"] = %"provided metadata"

proc loadBatch(directory: string): Batch =
  ## Requires complete verified five-seat fast games and frozen requests.
  if fileExists(directory / "response-error.json"):
    raise newException(AwmError, "Fast batch has a saved error response")
  let
    request = readJson(directory / "request.json")
    meta = readJson(directory / "request.json.meta.json")
    summary = readJson(directory / "summary.json")
    manifest = readJson(directory / "manifest.json")
    response = readJson(directory / "response.json")
    seed = request.integer("seed")
    count = request.integer("num_episodes")
    roster = request.items("roster")
  if count notin 1 .. 10 or seed < int32.low.int or
    seed.int64 + count.int64 - 1 > int32.high.int64:
      raise newException(AwmError, "Invalid fast batch seed range")
  if roster.len != SeatCount or roster[0].kind != JObject or
    roster[0].integer("slot") != 0:
      raise newException(
        AwmError,
        "Fast batch needs candidate pinned at seat 0"
      )
  let
    player = roster[0].objectField("player")
    source = player.text("source")
  if player.len != 1 or source.strip.len == 0 or
    source.len > SourceLimit or '\0' in source:
      raise newException(AwmError, "Unknown or invalid candidate source")
  result.sourceHash = sha256(source).toHex.toLowerAscii
  for i in 1 ..< SeatCount:
    if roster[i].kind != JObject or roster[i].integer("slot") != -1:
      raise newException(AwmError, "Opponent must be an unpinned policy_ref")
    let opponent = roster[i].objectField("player")
    if opponent.len != 1:
      raise newException(AwmError, "Opponent requires one policy_ref")
    result.opponents.add opponent.text("policy_ref")
  if meta.text("service") != "fast-xp" or meta.text("game") != "awm" or
    meta.integer("players") != SeatCount or
    meta.integer("candidate_slot") != 0 or
    summary.text("service") != "fast-xp" or
    summary.integer("players") != SeatCount or
    summary.integer("candidate_slot") != 0:
      raise newException(AwmError, "Only five-seat fast-XP artifacts accepted")
  var metaOpponents: seq[string]
  for opponent in meta.items("opponents"):
    if opponent.kind != JObject:
      raise newException(AwmError, "Invalid opponent metadata")
    metaOpponents.add opponent.text("policy_ref")
  if meta.hasKey("extra_seat_policy_ref") and
    meta["extra_seat_policy_ref"].kind != JNull:
      metaOpponents.add meta.text("extra_seat_policy_ref")
  if metaOpponents != result.opponents:
    raise newException(AwmError, "Request and metadata opponents differ")
  if response.integer("http_status") != 200 or
    not response.text("content_type").startsWith("application/zip") or
    manifest.text("game") != "awm" or
    manifest.text("request_id") != response.text("request_id"):
      raise newException(AwmError, "Fast response or manifest failed")
  if summary.integer("seed") != seed or
    summary.integer("requested") != count or
    summary.integer("games") != count or
    summary.integer("failed") != 0 or
    summary.integer("games_with_disabled_bots") != 0 or
    summary.integer("candidate_failures_detected") != 0:
      raise newException(AwmError, "Fast batch is incomplete or has failures")
  let
    records = manifest.items("games")
    episodes = summary.items("episodes")
  if records.len != count or episodes.len != count:
    raise newException(AwmError, "Fast batch game counts differ")
  var
    seenRecords, seenEpisodes: HashSet[int]
    wins = 0
  result.episodes = newSeq[Episode](count)
  for record in records:
    if record.kind != JObject:
      raise newException(AwmError, "Invalid manifest game")
    let index = record.integer("index")
    if index notin 0 ..< count or index in seenRecords or
      record.integer("seed") != seed + index:
        raise newException(AwmError, "Manifest seed or index differs")
    seenRecords.incl index
    if record.text("status") != "completed" or
      record.integer("http_status") != 200 or
      record.integer("active_bots") != SeatCount:
        raise newException(AwmError, "Fast game is incomplete or disabled")
    let seating = record.integers("roster_entries_by_slot")
    var seats: set[0 .. SeatCount - 1]
    if seating.len != SeatCount or seating[0] != 0:
      raise newException(AwmError, "Invalid five-seat manifest mapping")
    for entry in seating:
      if entry notin 0 ..< SeatCount or entry in seats:
        raise newException(AwmError, "Invalid five-seat manifest mapping")
      seats.incl entry
    result.episodes[index] = Episode(
      seed: seed + index,
      index: index,
      seating: seating
    )
  for episode in episodes:
    if episode.kind != JObject:
      raise newException(AwmError, "Invalid verified episode")
    let index = episode.integer("index")
    if index notin 0 ..< count or index in seenEpisodes or
      episode.integer("seed") != seed + index:
        raise newException(AwmError, "Summary seed or index differs")
    seenEpisodes.incl index
    if episode.integer("http_status") != 200 or
      episode.integer("active_bots") != SeatCount or
      episode.integer("verified_ticks") <= 0 or
      not episode.boolean("game_over") or
      episode.boolean("candidate_failure_detected") or
      not episode.boolean("candidate_log_nonempty"):
        raise newException(AwmError, "Verified game is incomplete or failed")
    let
      seating = episode.integers("roster_entries_by_slot")
      classes = episode.integers("classes")
      living = episode.integers("living_seats")
      winner = episode.integer("engine_winner")
      won = winner == 0
    if seating != result.episodes[index].seating:
      raise newException(AwmError, "Summary and manifest seatings differ")
    if classes.len != SeatCount:
      raise newException(AwmError, "Verified game lacks five classes")
    for heroClass in classes:
      if heroClass notin 0 .. 2:
        raise newException(AwmError, "Unknown AWM hero class")
    if winner notin 0 ..< SeatCount or living != @[winner] or
      episode.boolean("candidate_win") != won or
      episode.boolean("engine_candidate_win") != won:
        raise newException(AwmError, "Summary is not an actual survivor win")
    result.episodes[index].classes = classes
    result.episodes[index].winner = winner
    result.episodes[index].won = won
    if won:
      inc wins
  if wins != summary.integer("wins"):
    raise newException(AwmError, "Summary wins disagree with verified games")
  result.attribution = attribution(directory, meta, response)

proc probability(gained, lost: int): float =
  ## Computes the exact one-sided paired binomial tail on discordant games.
  let total = gained + lost
  if total == 0:
    return 1.0
  var mass = -total.float * ln(2.0)
  for i in 0 .. total:
    if i >= gained:
      result += exp(mass)
    if i < total:
      mass += ln((total - i).float) - ln((i + 1).float)
  result = min(1.0, result)

proc batchCount(value: string): int =
  ## Requires a positive batch count for each independent seed cohort.
  try:
    result = parseInt(value)
  except ValueError as error:
    raise newException(AwmError, "Invalid batch count: " & error.msg)
  if result <= 0:
    raise newException(AwmError, "Batch count must be positive")

proc main() =
  ## Pairs numbered prefixes and optional extra disjoint prefix/count triples.
  if paramCount() < 4 or (paramCount() - 4) mod 3 != 0:
    raise newException(AwmError,
      "Usage: fast_scores BASELINE_PREFIX CANDIDATE_PREFIX BATCHES " &
      "OUTPUT_JSON [BASELINE_PREFIX CANDIDATE_PREFIX BATCHES ...]")
  var
    prefixes = @[[paramStr(1), paramStr(2)]]
    counts = @[batchCount(paramStr(3))]
    sources: array[2, string]
    opponents: seq[string]
    seen: HashSet[int]
    baselineWins, candidateWins, gained, lost, bothWon, bothLost: int
    classGames, baselineClassWins, candidateClassWins: array[3, int]
    count = counts[0]
    argument = 5
  while argument <= paramCount():
    prefixes.add [paramStr(argument), paramStr(argument + 1)]
    counts.add batchCount(paramStr(argument + 2))
    count += counts[^1]
    argument += 3
  let
    paired = newJArray()
    batches = newJArray()
    cohorts = newJArray()
  for cohort in 0 ..< prefixes.len:
    let
      priorGames = seen.len
      priorBaseline = baselineWins
      priorCandidate = candidateWins
      priorGained = gained
      priorLost = lost
      priorBothWon = bothWon
      priorBothLost = bothLost
    for i in 0 ..< counts[cohort]:
      let
        baseline = loadBatch(prefixes[cohort][0] & $i)
        candidate = loadBatch(prefixes[cohort][1] & $i)
      if cohort == 0 and i == 0:
        sources = [baseline.sourceHash, candidate.sourceHash]
        opponents = baseline.opponents
      if sources != [baseline.sourceHash, candidate.sourceHash]:
        raise newException(
          AwmError,
          "Cannot mix candidate source hashes per arm"
        )
      if baseline.opponents != opponents or candidate.opponents != opponents:
        raise newException(
          AwmError,
          "Cannot pair different opponent policy_refs"
        )
      if baseline.episodes.len != candidate.episodes.len:
        raise newException(
          AwmError,
          "Paired batches have different game counts"
        )
      batches.add %*{
        "index": batches.len,
        "cohort_index": cohort,
        "cohort_batch_index": i,
        "baseline": baseline.attribution,
        "candidate": candidate.attribution
      }
      for j in 0 ..< baseline.episodes.len:
        let
          previous = baseline.episodes[j]
          current = candidate.episodes[j]
        if previous.seed != current.seed or
          previous.classes != current.classes or
          previous.seating != current.seating:
            raise newException(
              AwmError,
              "Paired seed, classes or seatings differ"
            )
        if current.seed in seen:
          raise newException(
            AwmError,
            "Duplicate paired seed: " & $current.seed
          )
        seen.incl current.seed
        let ownClass = current.classes[0]
        inc classGames[ownClass]
        if previous.won:
          inc baselineWins
          inc baselineClassWins[ownClass]
        if current.won:
          inc candidateWins
          inc candidateClassWins[ownClass]
        if previous.won and current.won:
          inc bothWon
        elif previous.won:
          inc lost
        elif current.won:
          inc gained
        else:
          inc bothLost
        paired.add %*{
          "cohort_index": cohort,
          "seed": current.seed,
          "classes": current.classes,
          "roster_entries_by_slot": current.seating,
          "baseline_win": previous.won,
          "candidate_win": current.won
        }
    let
      cohortGames = seen.len - priorGames
      cohortGained = gained - priorGained
      cohortLost = lost - priorLost
    cohorts.add %*{
      "index": cohort,
      "baseline_prefix": absolutePath(prefixes[cohort][0]),
      "candidate_prefix": absolutePath(prefixes[cohort][1]),
      "num_batches": counts[cohort],
      "games_per_arm": cohortGames,
      "baseline_wins": baselineWins - priorBaseline,
      "candidate_wins": candidateWins - priorCandidate,
      "baseline_win_rate": (baselineWins - priorBaseline).float /
        cohortGames.float,
      "candidate_win_rate": (candidateWins - priorCandidate).float /
        cohortGames.float,
      "gained": cohortGained,
      "lost": cohortLost,
      "both_won": bothWon - priorBothWon,
      "both_lost": bothLost - priorBothLost,
      "one_sided_exact_mcnemar_p": probability(cohortGained, cohortLost)
    }
  let
    games = seen.len
    tail = probability(gained, lost)
    summary = %*{
      "service": "fast-xp",
      "players": SeatCount,
      "candidate_slot": 0,
      "baseline_prefix": absolutePath(paramStr(1)),
      "candidate_prefix": absolutePath(paramStr(2)),
      "num_batches": count,
      "num_cohorts": prefixes.len,
      "cohorts": cohorts,
      "baseline_source_sha256": sources[0],
      "candidate_source_sha256": sources[1],
      "opponents": opponents,
      "games_per_arm": games,
      "total_games": games * 2,
      "baseline_wins": baselineWins,
      "candidate_wins": candidateWins,
      "own_class": {
        "Archer": {
          "class": 0,
          "games_per_arm": classGames[0],
          "baseline_wins": baselineClassWins[0],
          "candidate_wins": candidateClassWins[0]
        },
        "Warrior": {
          "class": 1,
          "games_per_arm": classGames[1],
          "baseline_wins": baselineClassWins[1],
          "candidate_wins": candidateClassWins[1]
        },
        "Mage": {
          "class": 2,
          "games_per_arm": classGames[2],
          "baseline_wins": baselineClassWins[2],
          "candidate_wins": candidateClassWins[2]
        }
      },
      "baseline_win_rate": baselineWins.float / games.float,
      "candidate_win_rate": candidateWins.float / games.float,
      "gained": gained,
      "lost": lost,
      "both_won": bothWon,
      "both_lost": bothLost,
      "discordant_pairs": gained + lost,
      "one_sided_paired_binomial_p": tail,
      "one_sided_exact_mcnemar_p": tail,
      "batches": batches,
      "pairs": paired,
      "scoring_scope": "Five-seat fast screening; separate from regular XP",
      "source_attribution": "SHA-256 of exact inline saved request source",
      "endpoint_attribution":
        "Saved directory/request IDs and provided metadata"
    }
  try:
    createDir(paramStr(4).parentDir)
    writeFile(paramStr(4), summary.pretty & "\n")
  except IOError, OSError:
    raise newException(AwmError,
      "Cannot save fast score: " & getCurrentExceptionMsg())
  echo &"Fast paired {games} seeds: baseline {baselineWins}/{games}, " &
    &"candidate {candidateWins}/{games}; gained {gained}, lost {lost}, " &
    &"one-sided exact paired p = {tail:.6f}."

main()
