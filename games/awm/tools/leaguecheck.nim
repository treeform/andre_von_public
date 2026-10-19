## Replays real league games' exact seeds and seatings on fast-XP and
## compares classes and winners, to test whether fast-XP matches the league.
##
##   leaguecheck [MAX_GAMES]
##
## Reads `eps/league/status_rounds.json` and `eps/league/replays/`.

import
  std/[json, os, strformat, strutils, tables],
  curly, zippy, zippy/ziparchives,
  sim, match, replays

const Base = "https://fast-xp-request-staging.tail0f4a29.ts.net"

proc decode(bytes: string): ReplayData =
  ## Decodes a raw or gzip replay.
  var raw = bytes
  if raw.len > 2 and raw[0] == '\x1f' and raw[1] == '\x8b':
    raw = uncompress(raw, dfGzip)
  decodeReplayFile(ReplayGame, ReplayGameVersion, raw, ReplayData)

proc winner(data: ReplayData): int =
  ## Applies a replay's actions and returns the winning seat, or -1.
  var game = newGame(data.header.setup.heroClasses, data.header.setup.seed)
  for action in data.actions:
    discard game.applyAction(action)
  if game.gameOver: game.winner else: -1

proc main() =
  ## Requests each league game's twin and reports agreement.
  let
    limit = if paramCount() >= 1: parseInt(paramStr(1)) else: 20
    root = currentSourcePath().parentDir.parentDir / "eps" / "league"
    status = parseJson(readFile(root / "status_rounds.json"))
    temp = getTempDir() / "leaguecheck.zip"
  let curl = newCurly(4)
  defer:
    curl.close()
  var same, differ, checked = 0
  var winsByLabel: CountTable[string]
  for episode in status["episodes"]:
    if checked >= limit:
      break
    let path = root / "replays" / episode["job_id"].getStr & ".replay"
    if not fileExists(path):
      continue
    let league = decode(readFile(path))
    var labels = newSeq[string](episode["participants"].len)
    for p in episode["participants"]:
      labels[p["position"].getInt] = p["label"].getStr
    var roster = newJArray()
    let ours = getEnv("AWM_OURS")
    for slot, label in labels:
      if ours.len > 0 and label.startsWith("radogost"):
        roster.add %*{"slot": slot, "player": {"source": readFile(ours)}}
      else:
        roster.add %*{"slot": slot, "player": {"policy_ref": label}}
    let body = %*{"seed": league.header.setup.seed, "roster": roster,
      "num_episodes": 1}
    var headers: HttpHeaders
    headers["Content-Type"] = "application/json"
    let response = curl.post(Base & "/v1/games/awm/run", headers, $body,
      timeout = 600)
    if response.code != 200:
      echo "HTTP ", response.code, " ", response.body[0 ..< min(200, response.body.len)]
      continue
    writeFile(temp, response.body)
    let reader = openZipArchive(temp)
    let twin = decode(reader.extractFile("replay.replay"))
    reader.close()
    inc checked
    let
      a = league.winner
      b = twin.winner
      classesMatch = league.header.setup.classes == twin.header.setup.classes
    if b >= 0:
      winsByLabel.inc labels[b].split(':')[0]
    if a == b and classesMatch and league.actions.len == twin.actions.len:
      inc same
    else:
      inc differ
    echo &"seed {league.header.setup.seed}: league winner {a} " &
      &"({(if a >= 0: labels[a] else: \"-\")}) actions {league.actions.len} " &
      &"classes {league.header.setup.classes}; fast winner {b} " &
      &"({(if b >= 0: labels[b] else: \"-\")}) actions {twin.actions.len} " &
      &"classes {twin.header.setup.classes}"
  echo &"identical {same}, different {differ}"
  echo "fast-XP winners: ", winsByLabel

main()
