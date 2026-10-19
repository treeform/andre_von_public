## Pulls completed AWM league rounds and reports real league results:
## per-policy game wins and wins by ring position relative to our seat.
##
##   rounds [MAX_ROUNDS]
##
## Episodes are saved as `eps/league/status_rounds.json` in the XP status
## shape, with replay URLs, so `stats.nim` and `artifacts.nim` can use them.

import
  std/[httpclient, json, os, strformat, strutils, tables]

const
  Api = "https://softmax.com/api/observatory/v2"
  League = "league_ad6dc809-4696-46f5-99a5-fc2b1c58d082"
  Dash = "https://softmaxdash-nginx.tail0f4a29.ts.net/league/" &
    "archers-warriors-mages.json"
  Player = "Andre von Auto"

proc userToken(): string =
  ## Returns the user bearer token from the shared credentials file.
  var inTokens = false
  for line in readFile(getHomeDir() / ".softmax/credentials.yaml").splitLines:
    if line.startsWith("tokens:"):
      inTokens = true
    elif inTokens and "https" in line:
      return line.split(": ")[^1].strip(chars = {'"', ' '})
  quit("rounds: no user token", 1)

proc main() =
  ## Fetches round episodes and prints league tallies.
  let limit = if paramCount() >= 1: parseInt(paramStr(1)) else: 40
  let client = newHttpClient(timeout = 60_000)
  defer:
    client.close()
  client.headers = newHttpHeaders({"Authorization": "Bearer " & userToken()})
  # Every round, newest first, through the cursor-paged rounds route.
  var allRounds = newJArray()
  var cursor = ""
  while true:
    var url = Api & "/rounds?league_id=" & League & "&limit=100"
    if cursor.len > 0:
      url.add "&cursor=" & cursor
    let page = parseJson(client.getContent(url))
    for r in page["entries"]:
      allRounds.add r
    if not page.hasKey("next_cursor") or page["next_cursor"].kind != JString or
        page["next_cursor"].getStr.len == 0:
      break
    cursor = page["next_cursor"].getStr
  var
    episodes = newJArray()
    wins, games: CountTable[string]
    relationWins, relationGames: CountTable[string]
    count = 0
  for round in allRounds:
    if round["status"].getStr != "completed" or count >= limit:
      continue
    inc count
    let body = parseJson(client.getContent(
      Api & "/rounds/" & round["id"].getStr & "/episodes"))
    for entry in body["entries"]:
      if entry["status"].getStr != "completed":
        continue
      var labels: Table[string, string]
      var seats: seq[string]
      for p in entry["participants"]:
        let label = p["policy_name"].getStr & ":v" & $p["version"].getInt
        labels[p["policy_version_id"].getStr] = label
        seats.add label
        p["label"] = %label
      var winner = ""
      for s in entry["scores"]:
        if s["score"].getFloat > 0:
          winner = labels[s["policy_version_id"].getStr]
      entry["job_id"] = %(entry["replay_url"].getStr.splitFile.name)
      episodes.add entry
      var ours = -1
      for i in 0 ..< entry["participants"].len:
        if entry["participants"][i]["player_name"].getStr == Player:
          ours = i
      for label in seats:
        games.inc label
      if winner.len > 0:
        wins.inc winner
      if ours >= 0:
        # Winner's seat relative to ours: +1 is the next seat, -1 the one
        # that attacks us at the start.
        let n = seats.len
        for i, label in seats:
          let relation = (i - ours + n) mod n
          let key = $relation & " " & label.split(':')[0]
          relationGames.inc key
          if label == winner:
            relationWins.inc key
  createDir(currentSourcePath().parentDir.parentDir / "eps" / "league")
  writeFile(currentSourcePath().parentDir.parentDir / "eps" / "league" /
    "status_rounds.json", $(%*{"id": "league_rounds", "episodes": episodes}))
  echo count, " rounds, ", episodes.len, " games"
  for label, n in games:
    echo &"  {label}: {wins[label]}/{n} ({100.0 * wins[label].float / n.float:.1f}%)"
  echo "wins by seat after ours (0 = ours, 1 = next, 4 = attacker):"
  for key, n in relationGames:
    echo &"  {key}: {relationWins[key]}/{n}"

main()
