## Summarizes one policy's hero across the replays of hosted XP episodes.
##
##   nim r -d:ssl games/gods-of-the-arena/tools/gota_arm.nim <stats binary> <policy> <eps.json,...> [cache dir]
##
## Downloads each completed episode's replay (cached, gunzipped), runs the
## gota_stats binary built for the hosted engine eight at a time (rows are
## cached next to the tape), keeps the rows of every seat the policy played,
## and prints the mean of each stat plus the share of games that ended
## before the time limit. The policy may be a comma-free name prefix.
## Set GOTA_CLASS=<class index> to keep only heroes of that class, and
## GOTA_WON=1 or 0 to keep only heroes whose team won or did not win.

import
  std/[httpclient, json, os, osproc, strutils, strformat, tables],
  zippy

const
  Keys = [
    "score", "xp", "xp_god", "xp_herokill", "xp_lasthit", "xp_building",
    "minutes", "won", "target_god", "target_building", "target_hero",
    "target_creep", "time_near_enemy_god", "time_near_own_god", "allies_near", "kills",
    "deaths", "building_kills", "hp_mean", "time_below25", "time_below50",
    "time_near_enemy_tower", "attacks_pm", "walks_pm", "casts_pm",
    "itemuses_pm", "lowhp_walks", "alive_share", "level", "gold_earned",
    "buy_poison", "items_consumed", "buy_gear", "xp_neutral", "neutral_kills",
    "tower_kills"]
  LimitMinutes = 19.9
  Workers = 8
  Classes = [
    "VanguardKnight", "Ranger", "Arcanist", "DruidWarden", "DemonHunter",
    "DeathKnight", "Crossbowman", "Lich", "Warlock", "Berserker"]

proc fetchReplay(url, path: string) =
  ## Saves the raw replay tape at path, gunzipping when needed.
  if fileExists(path):
    return
  var body = newHttpClient(timeout = 120_000).getContent(url)
  if body.len >= 2 and body[0] == '\x1f' and body[1] == '\x8b':
    body = uncompress(body, dataFormat = dfGzip)
  writeFile(path, body)

proc parseRow(line: string): Table[string, float] =
  ## Parses "row N key=value ..." into a table, the position under "row".
  let parts = line.splitWhitespace()
  result["row"] = parseFloat(parts[1])
  for part in parts[2 .. ^1]:
    let eq = part.find('=')
    if eq > 0:
      try:
        result[part[0 ..< eq]] = parseFloat(part[eq + 1 .. ^1].strip(chars = {'.'}))
      except ValueError:
        discard

proc main() =
  if paramCount() < 3:
    quit("usage: gota_arm <stats binary> <policy> <eps.json,...> [cache dir]", 2)
  let
    binary = paramStr(1)
    policy = paramStr(2)
    cache =
      if paramCount() >= 4:
        paramStr(4)
      else:
        getTempDir() / "gota_arm_cache"
  createDir(cache)
  var
    games: seq[(string, seq[int])]
    commands: seq[string]
  for path in paramStr(3).split(','):
    for episode in parseFile(path).getElems():
      if episode{"status"}.getStr != "completed":
        continue
      let url = episode{"replay_url"}.getStr
      if url.len == 0:
        continue
      var positions: seq[int]
      for p in episode["participants"]:
        if p{"policy_name"}.getStr.startsWith(policy):
          positions.add p["position"].getInt
      if positions.len == 0:
        continue
      let
        id = episode["id"].getStr
        tape = cache / id & ".replay"
        rows = cache / id & ".rows"
      if not fileExists(rows):
        try:
          fetchReplay(url, tape)
        except CatchableError:
          try:
            fetchReplay(url, tape)
          except CatchableError as e:
            echo "skip ", id, ": ", e.msg
            continue
        commands.add binary & " " & quoteShell(tape) & " > " & quoteShell(rows)
      games.add((id, positions))
  if commands.len > 0:
    discard execProcesses(
      commands,
      options = {poEvalCommand, poUsePath},
      n = Workers
    )
  var
    sums: Table[string, float]
    heroes = 0
    ended = 0
    classCounts: array[10, int]
    onlyClass = parseInt(getEnv("GOTA_CLASS", "-1"))
    onlyWon = parseInt(getEnv("GOTA_WON", "-1"))
    classScores: array[10, float]
  for (id, positions) in games:
    let rows = cache / id & ".rows"
    if not fileExists(rows):
      continue
    for line in readFile(rows).splitLines:
      if not line.startsWith("row "):
        continue
      let row = parseRow(line)
      if row["row"].int notin positions:
        continue
      let heroClass = row.getOrDefault("class").int
      if onlyClass >= 0 and heroClass != onlyClass:
        continue
      if onlyWon >= 0 and row.getOrDefault("won").int != onlyWon:
        continue
      inc heroes
      if heroClass in 0 .. 9:
        inc classCounts[heroClass]
        classScores[heroClass] += row.getOrDefault("score")
      if row.getOrDefault("minutes") < LimitMinutes:
        inc ended
      for key in Keys:
        sums[key] = sums.getOrDefault(key) + row.getOrDefault(key)
  if heroes == 0:
    quit("no games for " & policy)
  echo &"{policy}: {heroes} hero-games, {ended.float / heroes.float:.3f} ended before the limit"
  for key in Keys:
    echo &"  {key:<22} {sums.getOrDefault(key) / heroes.float:10.3f}"
  echo "  class: share, mean score"
  for i in 0 .. 9:
    if classCounts[i] > 0:
      let share = classCounts[i].float / heroes.float
      let mean = classScores[i] / classCounts[i].float
      echo &"    {Classes[i]:<16} {share:6.3f} {mean:8.0f}"

main()
