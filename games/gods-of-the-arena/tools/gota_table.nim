## Builds the policy comparison table from live league replays.
##
##   gota_table <stats binary> [--per 40] [--parallel 4] [--cache dir]
##     [--out stats.md] [--html stats.html]
##     [--ours-policy khors:vN] (count only that version in our column)
##   gota_table <stats binary> --h2h list.txt --opponent name [--html file]
##   gota_table <stats binary> --seats list.txt [--html file]
##     (seat mode: each list line is "<stats rows file> <seat> <column name>")
##     (head-to-head mode: each list line is "<stats rows file> <our team 0|1>")
##
## Reads the dash's completed rounds, finds every game holding one of the
## compared players, downloads its replay once (cached as stats rows), runs
## the replay stats extractor a few at a time, and averages each stat per
## column over that player's heroes. Columns: our policy first, then the
## three top rivals. Rows are grouped by how directly a policy controls them:
## direct (orders, movement, targets), semi-indirect (spending, items,
## class) and indirect (outcomes). The last column compares us with the
## rivals' average and flags large gaps.

import
  std/[httpclient, json, math, os, osproc, sets, strformat,
    strutils, tables],
  zippy

const
  Dash = "https://softmaxdash-nginx.tail0f4a29.ts.net/league/gods-of-the-arena.json"
  Api = "https://softmax.com/api/observatory/v2/rounds/"
  Columns = [
    ("khors", @["Andre von Auto"]),
    ("macromackie", @["macromackie"]),
    ("James Botts", @["James Botts"]),
    ("Evolver", @["Evolver"])
  ]
  Direct = ["orders_pm", "walks_pm", "attackmoves_pm", "attacks_pm",
    "casts_pm", "itemuses_pm", "dup_share", "rejected_pm", "tiles_pm",
    "target_hero", "target_creep", "target_building", "target_god",
    "time_enemy_half", "time_near_enemy_tower", "time_near_enemy_god",
    "time_near_own_god", "allies_near", "lowhp_walks",
    "creeps_near_pm", "lasthits_pm", "missed_pm", "ally_lasthits_pm",
    "lasthit_share", "exposed_share", "hide_hero", "hide_creep", "hide_any"]
  Semi = ["gold_spent", "gold_end", "buy_gear", "buy_heal", "buy_mana",
    "buy_poison", "buy_portal", "items_consumed", "buybacks", "buyback_gold"]
  Indirect = ["won", "kills", "deaths", "assists", "alive_share", "hp_mean",
    "time_below25", "level", "xp", "xp_lasthit", "xp_herokill",
    "xp_building", "xp_neutral", "neutral_kills", "building_kills",
    "tower_kills", "gold_earned", "minutes"]
  ClassNames = ["Vanguard", "Ranger", "Arcanist", "Druid", "DemonHunter",
    "DeathKnight", "Crossbowman", "Lich", "Warlock", "Berserker"]

type
  Column = object
    heroes: int
    sums: Table[string, float]
    classes: array[10, int]

proc userToken(): string =
  ## Returns the user (not player) bearer token from the credentials file.
  var inTokens = false
  for line in readFile(getHomeDir() / ".softmax/credentials.yaml").splitLines:
    if line.startsWith("tokens:"):
      inTokens = true
    elif inTokens and "https" in line:
      return line.split(": ")[^1].strip(chars = {'"', ' '})
  quit("no user token in credentials.yaml")

proc columnOf(player: string): int =
  ## Returns the column index of one player name, or -1.
  for i, (_, players) in Columns:
    if player in players:
      return i
  -1

proc fields(row: string): Table[string, string] =
  ## Splits one stats row into its key=value fields.
  for part in row.split(' '):
    let kv = part.split('=')
    if kv.len == 2:
      result[kv[0]] = kv[1]

proc main() =
  if paramCount() < 1:
    quit("usage: gota_table <stats binary> [--per 40] [--parallel 4] [--cache dir] [--out file]")
  let stats = paramStr(1)
  var
    per = 40
    parallel = 4
    cache = getTempDir() / "gota_table"
    outPath = ""
    htmlPath = ""
    oursPolicy = ""
    h2hList = ""
    seatsList = ""
    opponent = "opponent"
    i = 2
  while i <= paramCount():
    case paramStr(i)
    of "--per": per = parseInt(paramStr(i + 1))
    of "--parallel": parallel = parseInt(paramStr(i + 1))
    of "--cache": cache = paramStr(i + 1)
    of "--out": outPath = paramStr(i + 1)
    of "--html": htmlPath = paramStr(i + 1)
    of "--ours-policy": oursPolicy = paramStr(i + 1)
    of "--h2h": h2hList = paramStr(i + 1)
    of "--opponent": opponent = paramStr(i + 1)
    of "--seats": seatsList = paramStr(i + 1)
    else: quit("unknown option " & paramStr(i))
    i += 2
  createDir(cache)
  var
    names: seq[string]
    rowsFiles: seq[(string, Table[int, int])]
    rounds: seq[int]
  if h2hList.len > 0:
    ## Head-to-head mode: each line is "<stats rows file> <our team 0|1>".
    names = @["khors", opponent]
    for line in readFile(h2hList).splitLines:
      let parts = line.splitWhitespace
      if parts.len < 2:
        continue
      var seats: Table[int, int]
      for seat in 0 ..< 10:
        seats[seat] = (if (seat div 5) == parseInt(parts[1]): 0 else: 1)
      rowsFiles.add((parts[0], seats))
  elif seatsList.len > 0:
    ## Seat mode: each line is "<stats rows file> <seat> <column name>", so
    ## one seat of each game is compared, e.g. the same rosters with
    ## different bots in our seat.
    for line in readFile(seatsList).splitLines:
      let parts = line.splitWhitespace
      if parts.len < 3:
        continue
      if parts[2] notin names:
        names.add parts[2]
      var seats: Table[int, int]
      seats[parseInt(parts[1])] = names.find(parts[2])
      rowsFiles.add((parts[0], seats))
  else:
    for (name, _) in Columns:
      names.add name
  if h2hList.len == 0 and seatsList.len == 0:
    let client = newHttpClient(timeout = 120_000)
    let league = parseJson(client.getContent(Dash))
    client.headers = newHttpHeaders({"Authorization": "Bearer " & userToken()})
  
    ## Pick games until every column has `per` games (newest rounds first).
    var
      picked: seq[(string, string, Table[int, int])]
      gamesPer: array[Columns.len, int]
    for round in league["rounds"]:
      if round{"status"}.getStr != "completed":
        continue
      rounds.add round["number"].getInt
      let body = parseJson(client.getContent(Api & round["id"].getStr & "/episodes"))
      for episode in body["entries"]:
        if episode{"status"}.getStr != "completed" or
          episode{"replay_url"}.getStr.len == 0:
            continue
        var seats: Table[int, int]
        var useful = false
        for p in episode["participants"]:
          let column = columnOf(p{"player_name"}.getStr)
          let policyRef = p{"policy_name"}.getStr & ":v" & $p{"version"}.getInt
          if column == 0 and oursPolicy.len > 0 and policyRef != oursPolicy:
            continue
          if column >= 0:
            seats[p["position"].getInt] = column
            if gamesPer[column] < per:
              useful = true
        if not useful:
          continue
        var counted: HashSet[int]
        for _, column in seats:
          if column notin counted:
            inc gamesPer[column]
            counted.incl column
        picked.add((episode["id"].getStr, episode["replay_url"].getStr, seats))
  
    ## Download and extract the replays not cached yet, a few at a time.
    ## Replays are public S3 objects: no observatory credential.
    let s3 = newHttpClient(timeout = 120_000)
    var commands: seq[string]
    for (id, url, _) in picked:
      let rows = cache / id & ".rows"
      if fileExists(rows):
        continue
      let raw = cache / id & ".replay"
      var data = s3.getContent(url)
      if data.len > 2 and data[0] == '\x1f' and data[1] == '\x8b':
        data = uncompress(data, dfGzip)
      writeFile(raw, data)
      commands.add quoteShell(stats) & " " & quoteShell(raw) & " > " &
        quoteShell(rows) & " 2>/dev/null; rm -f " & quoteShell(raw)
    if commands.len > 0:
      echo &"extracting {commands.len} replays, {parallel} at a time"
      discard execProcesses(commands, n = parallel, options = {poEvalCommand})
    for (id, _, seats) in picked:
      rowsFiles.add((cache / id & ".rows", seats))

  ## Average every stat per column over that column's heroes.
  var columns = newSeq[Column](names.len)
  var games = 0
  for (rows, seats) in rowsFiles:
    if not fileExists(rows):
      continue
    inc games
    for line in readFile(rows).splitLines:
      if not line.startsWith("row "):
        continue
      let seat = parseInt(line.split(' ')[1])
      if seat notin seats:
        continue
      let column = seats[seat]
      let f = fields(line)
      inc columns[column].heroes
      let heroClass = parseInt(f.getOrDefault("class", "-1"))
      if heroClass in 0 .. 9:
        inc columns[column].classes[heroClass]
      for key, value in f:
        try:
          columns[column].sums.mgetOrPut(key, 0.0) += parseFloat(value)
        except ValueError:
          discard

  proc mean(column: Column, key: string): float =
    if column.heroes == 0: NaN
    else: column.sums.getOrDefault(key, 0.0) / column.heroes.float

  proc gapOf(ours: float, rivals: seq[float]): string =
    ## Labels our value against the rivals' average: LOW, HIGH or "".
    if rivals.len == 0 or ours.isNaN:
      return ""
    let average = rivals.sum / rivals.len.float
    if average.abs > 0.0001:
      let ratio = ours / average
      if ratio < 0.67: return "LOW x" & formatFloat(ratio, ffDecimal, 2)
      if ratio > 1.5: return "HIGH x" & formatFloat(ratio, ffDecimal, 2)
    elif ours.abs > 0.0001:
      return "HIGH (rivals 0)"
    ""

  var
    report = ""
    html = ""
  let summary =
    if h2hList.len > 0: &"Head-to-head, {games} games, five khors against five {opponent}. Heroes per column: "
    elif seatsList.len > 0: &"Seat comparison, {games} games, one seat per game (same rosters and seeds per bot). Heroes per column: "
    else: &"Rounds {rounds.min}-{rounds.max}, {games} games. Heroes per column: "
  var counts = ""
  for i, name in names:
    counts.add &"{name} {columns[i].heroes}" & (if i < names.high: ", " else: ".")
  report.add &"# GotA policy stats\n\n{summary}{counts}\n\n"
  report.add "Gap compares khors with the rivals' average: LOW below 0.67x, HIGH above 1.5x.\n"
  html.add """<!doctype html><html><head><meta charset="utf-8"><title>GotA policy stats</title>
<style>
:root{--bg:#fbfaf8;--fg:#24292f;--muted:#6e7781;--line:#e4e1dc;--head:#f1eee9;--miss:#fbe9e7;--missline:#c0392b}
@media (prefers-color-scheme: dark){:root{--bg:#16181b;--fg:#e6e6e6;--muted:#9aa0a6;--line:#2c2f33;--head:#1f2226;--miss:#3a2224;--missline:#e06c5f}}
body{background:var(--bg);color:var(--fg);font:14px/1.45 -apple-system,system-ui,sans-serif;margin:24px auto;max-width:980px;padding:0 16px}
h1{font-size:22px;margin:0 0 4px}h2{font-size:15px;margin:28px 0 8px;color:var(--muted);font-weight:600;text-transform:uppercase;letter-spacing:.04em}
p{color:var(--muted);margin:4px 0}
table{border-collapse:collapse;width:100%;font-variant-numeric:tabular-nums}
th,td{padding:5px 10px;border-bottom:1px solid var(--line);text-align:right}
th:first-child,td:first-child{text-align:left}
th{background:var(--head);font-weight:600}
td.ours,th.ours{font-weight:600}
tr.miss td{background:var(--miss)}tr.miss td:first-child{box-shadow:inset 3px 0 0 var(--missline)}
td.gap{color:var(--missline);font-weight:600;white-space:nowrap}
</style></head><body><h1>GotA policy stats</h1>"""
  html.add &"<p>{summary}{counts}</p><p>Rows in red: khors is out of line with the rivals' average (below 0.67x or above 1.5x).</p>"

  proc htmlHeader(first: string): string =
    result = &"<table><tr><th>{first}</th>"
    for i, name in names:
      result.add (if i == 0: "<th class=\"ours\">" else: "<th>") & name & "</th>"

  proc section(title: string, keys: openArray[string]) =
    report.add &"\n## {title}\n\n| stat |"
    for name in names:
      report.add &" {name} |"
    report.add " gap |\n|---|"
    for _ in names:
      report.add "---:|"
    report.add "---|\n"
    html.add &"<h2>{title}</h2>" & htmlHeader("stat") & "<th>gap</th></tr>"
    for key in keys:
      var
        rivals: seq[float]
        cells = ""
      report.add &"| {key} |"
      for i in 0 ..< names.len:
        let value = columns[i].mean(key)
        let text = formatFloat(value, ffDecimal, 2)
        report.add " " & text & " |"
        cells.add (if i == 0: "<td class=\"ours\">" else: "<td>") & text & "</td>"
        if i > 0 and not value.isNaN:
          rivals.add value
      let gap = gapOf(columns[0].mean(key), rivals)
      report.add &" {gap} |\n"
      html.add (if gap.len > 0: "<tr class=\"miss\">" else: "<tr>") &
        &"<td>{key}</td>{cells}<td class=\"gap\">{gap}</td></tr>"
    html.add "</table>"

  section("Direct control (orders, movement, targets)", Direct)
  section("Semi-indirect (spending and items)", Semi)
  report.add "\n## Semi-indirect (class picks, share of heroes)\n\n| class |"
  for name in names:
    report.add &" {name} |"
  report.add "\n|---|"
  for _ in names:
    report.add "---:|"
  report.add "\n"
  html.add "<h2>Semi-indirect (class picks, share of heroes)</h2>" & htmlHeader("class") & "</tr>"
  for c, className in ClassNames:
    var
      rivals: seq[float]
      cells = ""
    report.add &"| {className} |"
    for i in 0 ..< names.len:
      let share =
        if columns[i].heroes == 0: 0.0
        else: columns[i].classes[c] / columns[i].heroes
      let text = formatFloat(share, ffDecimal, 2)
      report.add " " & text & " |"
      cells.add (if i == 0: "<td class=\"ours\">" else: "<td>") & text & "</td>"
      if i > 0:
        rivals.add share
    report.add "\n"
    let
      ours = if columns[0].heroes == 0: 0.0 else: columns[0].classes[c] / columns[0].heroes
      average = rivals.sum / max(1, rivals.len).float
      miss = abs(ours - average) >= 0.25
    html.add (if miss: "<tr class=\"miss\">" else: "<tr>") & &"<td>{className}</td>{cells}</tr>"
  html.add "</table>"
  section("Indirect (outcomes)", Indirect)
  html.add "</body></html>\n"
  echo report
  if outPath.len > 0:
    writeFile(outPath, report)
  if htmlPath.len > 0:
    writeFile(htmlPath, html)
    echo "html: ", htmlPath

main()
