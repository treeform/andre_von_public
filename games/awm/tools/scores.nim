import std/[algorithm, json, math, os, sets, strformat]

type AwmError = object of CatchableError

proc probability(wins, games: int, rate: float): float =
  ## Computes the exact upper binomial tail against an equal-seat win rate.
  var mass = pow(1 - rate, games.float)
  for i in 0 .. games:
    if i >= wins:
      result += mass
    if i < games:
      mass *= (games - i).float / (i + 1).float * rate / (1 - rate)

proc combination(total, chosen: int): float =
  ## Returns a log combination without overflowing factorials.
  let count = min(chosen, total - chosen)
  for i in 1 .. count:
    result += ln((total - count + i).float / i.float)

proc improvement(wins, games, previousWins, previousGames: int): float =
  ## Computes Fisher's exact upper tail for two independent hosted batches.
  let
    totalWins = wins + previousWins
    denominator = combination(games + previousGames, totalWins)
  for i in max(wins, totalWins - previousGames) .. min(games, totalWins):
    result += exp(combination(games, i) +
      combination(previousGames, totalWins - i) - denominator)

proc readJson(path: string): JsonNode =
  ## Parses a saved hosted result with a game-specific diagnostic.
  try:
    result = parseJson(readFile(path))
  except JsonParsingError as error:
    raise newException(AwmError, "Invalid result JSON: " & error.msg)

proc sourceRelease(node: JsonNode): tuple[id, version: string] =
  ## Requires immutable game identity and version for score comparisons.
  for key in ["coworld_id", "coworld_version"]:
    if not node.hasKey(key) or node[key].kind != JString or
      node[key].getStr.len == 0:
        raise newException(AwmError, "Missing source release metadata: " & key)
  (node["coworld_id"].getStr, node["coworld_version"].getStr)

proc requireComplete(request: JsonNode) =
  ## Rejects statistical comparisons before every requested episode finishes.
  if request["status"].getStr != "completed" or
    not request.hasKey("episode_count") or
    request["episode_count"].kind != JInt:
      raise newException(AwmError, "Hosted batch is not complete")
  let expected = request["episode_count"].getInt
  var completed = 0
  for episode in request["episodes"]:
    if episode["status"].getStr == "completed":
      inc completed
  if expected <= 0 or completed != expected or
    request["episodes"].len != expected:
      raise newException(AwmError, "Hosted batch is not complete")

proc requireCompleteSummary(summary: JsonNode) =
  ## Requires the prior summary to account for every requested game.
  if summary["status"].getStr != "completed" or
    not summary.hasKey("episode_count") or
    summary["episode_count"].kind != JInt:
      raise newException(
        AwmError,
        "Hosted batch is not complete: prior summary"
      )
  let expected = summary["episode_count"].getInt
  if expected <= 0 or summary["games"].getInt != expected or
    summary["failed"].getInt != 0:
      raise newException(
        AwmError,
        "Hosted batch is not complete: prior summary"
      )

proc main() =
  ## Summarizes one hosted request without exposing credentials or URLs.
  ## Uses '-' for the previous summary to aggregate without a comparison.
  if paramCount() < 1:
    raise newException(AwmError,
      "Usage: scores status.json [summary.json] " &
      "[previous-summary.json|-] [additional-status.json ...]")
  let
    request = readJson(paramStr(1))
    release = sourceRelease(request)
    ids = %*[request["id"].getStr]
  if paramCount() > 2:
    requireComplete(request)
  var episodeCount = request["episode_count"].getInt
  for i in 4 .. paramCount():
    let additional = readJson(paramStr(i))
    requireComplete(additional)
    if sourceRelease(additional) != release:
      raise newException(AwmError, "Cannot combine different source releases")
    episodeCount += additional["episode_count"].getInt
    ids.add additional["id"]
    if additional["status"].getStr != "completed":
      request["status"] = %"running"
    for episode in additional["episodes"]:
      request["episodes"].add episode
  var
    games, wins, failed = 0
    seats, seatWins: seq[int]
    seen: HashSet[string]
    version = ""
    opponents: seq[string]
    playerCount = 0
    pairWins, pairLosses, pairTies = 0
  for episode in request["episodes"]:
    let id = episode["id"].getStr
    if not episode.hasKey("coworld_id") or
      episode["coworld_id"].kind != JString or
      episode["coworld_id"].getStr != release.id:
        raise newException(AwmError,
          "Episode source release does not match its request: " & id)
    if id in seen:
      raise newException(AwmError, "Duplicate hosted episode: " & id)
    seen.incl id
    if episode["status"].getStr == "failed":
      inc failed
    if episode["status"].getStr != "completed":
      continue
    for player in episode["participants"]:
      if player["policy_name"].getStr == "radogost":
        let currentVersion = player["policy_version_id"].getStr
        if version.len == 0:
          version = currentVersion
        if version != currentVersion:
          raise newException(AwmError, "Cannot combine different policies")
        var currentOpponents: seq[string]
        for other in episode["participants"]:
          if other["position"].getInt != player["position"].getInt:
            currentOpponents.add other["policy_version_id"].getStr
        currentOpponents.sort()
        if playerCount == 0:
          playerCount = currentOpponents.len + 1
          if playerCount notin 2 .. 7:
            raise newException(AwmError,
              "AWM hosted results must contain two to seven players")
          opponents = currentOpponents
          seats = newSeq[int](playerCount)
          seatWins = newSeq[int](playerCount)
        if opponents != currentOpponents:
          raise newException(AwmError, "Cannot combine different opponents")
        let position = player["position"].getInt
        if position notin 0 ..< playerCount:
          raise newException(AwmError,
            "Invalid AWM seat " & $position & " for " & $playerCount &
              " players")
        inc games
        inc seats[position]
        var ownScore = 0.0
        for score in episode["participant_scores"]:
          if score["position"].getInt == position:
            ownScore = score["score"].getFloat
          if score["position"].getInt == position and
            score["score"].getFloat > 0.5:
              inc wins
              inc seatWins[position]
        for score in episode["participant_scores"]:
          if score["position"].getInt == position:
            continue
          let otherScore = score["score"].getFloat
          if ownScore > otherScore:
            inc pairWins
          elif ownScore < otherScore:
            inc pairLosses
          else:
            inc pairTies
  let
    rate = if games > 0: wins.float / games.float else: 0.0
    nullRate = if playerCount > 0: 1.0 / playerCount.float else: 0.0
    tail = if games > 0: probability(wins, games, nullRate) else: 1.0
    pairs = pairWins + pairLosses + pairTies
    pairRate =
      if pairs > 0:
        (pairWins.float + pairTies.float * 0.5) / pairs.float
      else:
        0.0
    summary = %*{
      "id": request["id"].getStr,
      "ids": ids,
      "coworld_id": release.id,
      "coworld_version": release.version,
      "policy_version_id": version,
      "opponents": opponents,
      "players": playerCount,
      "episode_count": episodeCount,
      "status": request["status"].getStr,
      "games": games,
      "wins": wins,
      "failed": failed,
      "win_rate": rate,
      "seat_games": seats,
      "seat_wins": seatWins,
      "null_win_rate": nullRate,
      "pair_wins": pairWins,
      "pair_losses": pairLosses,
      "pair_ties": pairTies,
      "pair_rate_with_half_ties": pairRate,
      "one_sided_binomial_p": tail
    }
  echo &"Hosted {request[\"status\"].getStr}: {wins}/{games} wins " &
    &"({rate * 100:.1f}%), failures {failed}, p vs equal seats = {tail:.4f}"
  echo "Seats: ", seats, "; wins: ", seatWins
  echo &"Pairwise {pairWins}-{pairLosses}-{pairTies}: " &
    &"{pairRate * 100:.1f}% with half credit for ties"
  if paramCount() > 2 and paramStr(3) != "-":
    let previous = readJson(paramStr(3))
    requireCompleteSummary(previous)
    if sourceRelease(previous) != release:
      raise newException(AwmError, "Cannot compare different source releases")
    let
      previousGames = previous["games"].getInt
      previousWins = previous["wins"].getInt
      comparison = improvement(wins, games, previousWins, previousGames)
    if previous.hasKey("opponents") and previous["opponents"] != %opponents:
      raise newException(AwmError, "Prior batch used different opponents")
    summary["previous_games"] = %previousGames
    summary["previous_wins"] = %previousWins
    summary["one_sided_fisher_p"] = %comparison
    echo &"Improvement over {previousWins}/{previousGames}: " &
      &"one-sided Fisher p = {comparison:.4f}"
  if paramCount() > 1:
    writeFile(paramStr(2), summary.pretty & "\n")

main()
