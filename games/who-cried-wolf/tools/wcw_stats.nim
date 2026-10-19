## Who Cried Wolf policy stats table (the gen_stats.md method).
##
##   nim r -d:ssl --hints:off games/who-cried-wolf/tools/wcw_stats.nim \
##     [--rounds 60] [--ours volchok:v4] [--top a,b,c] [xreq_ ids...] \
##     [--out stats.md] [--html stats.html]
##
## Reads recent league rounds (and any experience requests given), finds
## every seat held by our policy or one of the top three rivals (from the
## dash standings unless --top is given), and averages each stat per
## column over that policy's seats. Rows are grouped by how directly a
## policy controls them: direct (ballots, speech, night actions),
## semi-indirect (how the table treats the seat) and indirect (outcomes).
## The gap column compares us with the rivals' average and flags rows
## below 0.67x or above 1.5x; flagged rows are tinted red in the HTML.

import
  std/[algorithm, httpclient, json, math, os, strformat, strutils, tables],
  fetches

const
  Dash = "https://softmaxdash-nginx.tail0f4a29.ts.net/league/" &
    "who-cried-wolf-competition-pilot.json"
  Ours = "Andre von Auto"
  RoleNames = ["seer", "priest", "guard", "chef", "dairy maid", "noble",
    "track reader", "alchemist", "sheep", "wolf"]
  Direct = [
    ("ballot_rate", "share of vote requests answered with a target"),
    ("ballot_rate_town", "same, while town"),
    ("ballot_rate_wolf", "same, while wolf"),
    ("ballot_rate_day1", "same, on day 1"),
    ("with_majority", "cast ballots on the day's top-voted player"),
    ("self_votes", "cast ballots on themselves"),
    ("town_aim", "town ballots on a wolf, 1.0 = chance"),
    ("wolf_on_pack", "wolf ballots on their own packmate"),
    ("speeches_per_day", "public speeches per day alive"),
    ("speech_chars", "characters per speech"),
    ("accusing_speeches", "speeches that set an accusation"),
    ("claim_talk", "speeches that say claim or reveal"),
    ("role_claims", "speeches claiming a role (I am the ...)"),
    ("replies", "speeches that reply to another speech"),
    ("questions", "speeches that ask a question"),
    ("names_per_speech", "other players named per speech"),
    ("accusing_day1", "day-1 speeches that set an accusation"),
    ("accuse_switches", "extra accusation targets per day"),
    ("vote_follows_accusation", "ballots on the seat they accused that day"),
    ("accuse_on_lynched", "accusations on that day's voted-out seat"),
    ("suspicion_reports", "town votes with a suspicion report"),
    ("night_use", "offered night abilities used on a target"),
    ("kills_on_voters", "wolf kill picks on someone who voted that day"),
    ("valid_actions", "requests answered validly (game metric)")
  ]
  Semi = [
    ("votes_received", "ballots against the seat per day alive"),
    ("accused_received", "accusations against the seat per day alive"),
    ("suspicion_on_town", "town reports on the seat while town, 1.0 = chance"),
    ("suspicion_on_wolf", "town reports on the seat while wolf, 1.0 = chance"),
    ("night_killed", "town seats killed at night")
  ]
  Indirect = [
    ("win", "games won"),
    ("win_town", "games won as town"),
    ("win_wolf", "games won as wolf"),
    ("score", "mean episode score"),
    ("read", "town read bonus"),
    ("hidden", "wolf hidden bonus"),
    ("survived", "share of the game survived"),
    ("lynched", "seats voted out"),
    ("lynched_day1", "seats voted out on day 1"),
    ("days_alive", "vote days alive")
  ]

type
  Column = object
    name: string
    policies: seq[string]
    exact: string
    seats: int
    stats: Table[string, (float, float)]

proc add(column: var Column, key: string, num: float, den = 1.0) =
  ## Adds one observation (numerator and denominator) to a stat.
  var cell = column.stats.getOrDefault(key)
  cell[0] += num
  cell[1] += den
  column.stats[key] = cell

proc value(column: Column, key: string): float =
  ## Returns a stat as the ratio of its sums, or NaN without data.
  let cell = column.stats.getOrDefault(key)
  if cell[1] <= 0: NaN else: cell[0] / cell[1]

proc matches(column: Column, label: string): bool =
  ## True when a seat label belongs to this column.
  if column.exact.len > 0:
    return label == column.exact
  label.split(":")[0] in column.policies

proc topRivals(count: int): seq[Column] =
  ## Reads the dash and returns the top rival players' policy names.
  let client = newHttpClient(timeout = 60_000)
  defer:
    client.close()
  let dash = parseJson(client.getContent(Dash))
  var standings: seq[(float, string)]
  for row in dash{"playerStandings"}:
    if row{"player"}.getStr() != Ours:
      standings.add (row{"rating"}.getFloat(), row{"player"}.getStr())
  standings.sort(proc(a, b: (float, string)): int = cmp(b[0], a[0]))
  for (_, player) in standings[0 ..< min(count, standings.len)]:
    var column = Column(name: player)
    for policy in dash{"activePolicies"}:
      if policy{"player"}.getStr() == player:
        let name = policy{"policy"}.getStr()
        if name notin column.policies:
          column.policies.add name
    result.add column

proc claimsRole(text: string): bool =
  ## True when a speech claims a role in the first person.
  let lower = text.toLowerAscii()
  for role in RoleNames:
    for prefix in ["i am the ", "i'm the ", "i am a ", "i'm a "]:
      if (prefix & role) in lower:
        return true
  false

proc tally(columns: var seq[Column], id: string) =
  ## Adds one episode's seats to every column that owns one of them.
  let meta = episode(id)
  let url = meta{"replay_url"}.getStr()
  if url.len == 0:
    return
  let
    data = replay(id, url)
    table = seats(meta, data)
  var owner: array[9, int]
  var any = false
  for slot in 0 ..< 9:
    owner[slot] = -1
    for c, column in columns:
      if column.matches(table[slot].label):
        owner[slot] = c
        any = true
  if not any:
    return
  var
    days, speeches, characters, accusing, claimTalk, roleClaims: array[9, int]
    votesReceived, accusedReceived, reports, townRequests: array[9, int]
    deathCause: array[9, string]
    deathDay: array[9, int]
    votedToday: array[9, bool]
    voteDay = 0
    names: array[9, string]
    accusedNow: array[9, seq[int]]
  proc wolf(slot: int): bool = table[slot].faction == "wolf"
  for event in data{"events"}:
    let
      payload = event{"payload"}
      day = event{"day"}.getInt()
    case payload{"kind"}.getStr()
    of "started":
      for seat in payload{"roster"}:
        names[seat{"slot"}.getInt()] = seat{"name"}.getStr().toLowerAscii()
    of "speech":
      let
        speech = payload{"speech"}
        slot = speech{"slot"}.getInt()
        text = speech{"text"}.getStr()
        lower = text.toLowerAscii()
        c = owner[slot]
      if c >= 0:
        columns[c].add("replies", float(speech{"replyTo"}.kind == JString))
        columns[c].add("questions", float('?' in text))
        var named = 0
        for other in 0 ..< 9:
          if other != slot and names[other].len > 0 and
            names[other].split(" (")[0] in lower:
              inc named
        columns[c].add("names_per_speech", named.float)
        if day == 1:
          columns[c].add("accusing_day1",
            float(speech{"accusation"}.kind == JInt))
      if speech{"accusation"}.kind == JInt:
        accusedNow[slot].add speech{"accusation"}.getInt()
      inc speeches[slot]
      characters[slot] += text.len
      if speech{"accusation"}.kind == JInt:
        inc accusing[slot]
        inc accusedReceived[speech{"accusation"}.getInt()]
      if "claim" in lower or "reveal" in lower:
        inc claimTalk[slot]
      if claimsRole(text):
        inc roleClaims[slot]
    of "ballots":
      var
        counts = initCountTable[int]()
        living, wolves = 0
      voteDay = day
      for slot in 0 ..< 9:
        votedToday[slot] = false
      for ballot in payload{"ballots"}:
        inc living
        if wolf(ballot{"slot"}.getInt()):
          inc wolves
        if ballot{"target"}.kind == JInt:
          counts.inc ballot{"target"}.getInt()
      let eliminated =
        if payload{"eliminated"}.kind == JInt: payload{"eliminated"}.getInt()
        else: -1
      for slot in 0 ..< 9:
        let c = owner[slot]
        if c < 0 or accusedNow[slot].len == 0:
          continue
        var targets: seq[int]
        for target in accusedNow[slot]:
          if target notin targets:
            targets.add target
        columns[c].add("accuse_switches", (targets.len - 1).float)
        if eliminated >= 0:
          for target in accusedNow[slot]:
            columns[c].add("accuse_on_lynched", float(target == eliminated))
      var leader = -1
      if counts.len > 0:
        counts.sort()
        var top: seq[int]
        for target, count in counts:
          if count == counts.largest[1]:
            top.add target
        if top.len == 1:
          leader = top[0]
      for ballot in payload{"ballots"}:
        let
          voter = ballot{"slot"}.getInt()
          voted = ballot{"target"}.kind == JInt
          target = if voted: ballot{"target"}.getInt() else: -1
        inc days[voter]
        if voted:
          inc votesReceived[target]
          votedToday[voter] = true
        if not wolf(voter):
          inc townRequests[voter]
        let c = owner[voter]
        if c < 0:
          continue
        columns[c].add("ballot_rate", float(voted))
        columns[c].add(
          if wolf(voter): "ballot_rate_wolf" else: "ballot_rate_town",
          float(voted)
        )
        if day == 1:
          columns[c].add("ballot_rate_day1", float(voted))
        if not voted:
          continue
        columns[c].add("with_majority", float(target == leader))
        if accusedNow[voter].len > 0:
          columns[c].add("vote_follows_accusation",
            float(target == accusedNow[voter][^1]))
        columns[c].add("self_votes", float(target == voter))
        if wolf(voter):
          if target != voter:
            columns[c].add("wolf_on_pack", float(wolf(target)))
        else:
          columns[c].add("town_aim", float(wolf(target)),
            wolves.float / max(1, living - 1).float)
    of "phase":
      if payload{"phase"}.getStr() == "day":
        for slot in 0 ..< 9:
          accusedNow[slot].setLen(0)
    of "suspicion":
      let reporter = payload{"slot"}.getInt()
      inc reports[reporter]
      var living, wolves = 0
      for slot in 0 ..< 9:
        if deathCause[slot].len == 0:
          inc living
          if wolf(slot):
            inc wolves
      let chance = wolves.float / max(1, living - 1).float
      for row in payload{"reports"}:
        let target = row{"slot"}.getInt()
        let c = owner[target]
        if c >= 0:
          columns[c].add(
            if wolf(target): "suspicion_on_wolf" else: "suspicion_on_town",
            row{"wolf"}.getFloat(),
            chance
          )
    of "night_choices":
      let slot = payload{"slot"}.getInt()
      let c = owner[slot]
      if c < 0:
        continue
      for action in payload{"actions"}:
        let used = action{"target"}.kind == JInt
        columns[c].add("night_use", float(used))
        if used and action{"ability"}.getStr() == "kill" and
          day == voteDay:
            columns[c].add("kills_on_voters",
              float(votedToday[action{"target"}.getInt()]))
    of "elimination":
      let slot = payload{"slot"}.getInt()
      deathCause[slot] = payload{"cause"}.getStr()
      deathDay[slot] = day
    else:
      discard
  for slot in 0 ..< 9:
    let c = owner[slot]
    if c < 0:
      continue
    let
      seat = table[slot]
      metrics = seat.metrics
      town = seat.faction != "wolf"
    inc columns[c].seats
    columns[c].add("speeches_per_day", speeches[slot].float,
      max(1, days[slot]).float)
    if speeches[slot] > 0:
      columns[c].add("speech_chars", characters[slot].float,
        speeches[slot].float)
      columns[c].add("accusing_speeches", accusing[slot].float,
        speeches[slot].float)
      columns[c].add("claim_talk", claimTalk[slot].float,
        speeches[slot].float)
      columns[c].add("role_claims", roleClaims[slot].float,
        speeches[slot].float)
    if town and townRequests[slot] > 0:
      columns[c].add("suspicion_reports", reports[slot].float,
        townRequests[slot].float)
    columns[c].add("valid_actions", metrics{"valid_actions"}.getFloat(1))
    columns[c].add("votes_received", votesReceived[slot].float,
      max(1, days[slot]).float)
    columns[c].add("accused_received", accusedReceived[slot].float,
      max(1, days[slot]).float)
    if town:
      columns[c].add("night_killed", float(deathCause[slot] == "wolf"))
    let win = metrics{"win"}.getInt().float
    columns[c].add("win", win)
    columns[c].add(if town: "win_town" else: "win_wolf", win)
    columns[c].add("score", seat.score)
    if metrics.hasKey("read"):
      columns[c].add("read", metrics{"read"}.getFloat())
    if metrics.hasKey("hidden"):
      columns[c].add("hidden", metrics{"hidden"}.getFloat())
    columns[c].add("survived", metrics{"survived"}.getFloat())
    columns[c].add("lynched", float(deathCause[slot] == "vote"))
    columns[c].add("lynched_day1",
      float(deathCause[slot] == "vote" and deathDay[slot] == 1))
    columns[c].add("days_alive", days[slot].float)

proc gapOf(ours: float, rivals: seq[float]): string =
  ## Labels our value against the rivals' average: LOW, HIGH or "".
  if rivals.len == 0 or ours.isNaN:
    return ""
  let average = rivals.sum / rivals.len.float
  if average.abs > 0.0001:
    let ratio = ours / average
    if ratio < 0.67:
      return "LOW x" & formatFloat(ratio, ffDecimal, 2)
    if ratio > 1.5:
      return "HIGH x" & formatFloat(ratio, ffDecimal, 2)
  elif ours.abs > 0.0001:
    return "HIGH (rivals 0)"
  ""

proc main() =
  ## Builds the table and writes Markdown and HTML.
  var
    rounds = "60"
    ours = "volchok:v4"
    top = ""
    outPath = ""
    htmlPath = ""
    extra: seq[string]
    i = 1
  while i <= paramCount():
    let argument = paramStr(i)
    case argument
    of "--rounds":
      rounds = paramStr(i + 1)
      inc i
    of "--ours":
      ours = paramStr(i + 1)
      inc i
    of "--top":
      top = paramStr(i + 1)
      inc i
    of "--out":
      outPath = paramStr(i + 1)
      inc i
    of "--html":
      htmlPath = paramStr(i + 1)
      inc i
    else:
      extra.add argument
    inc i
  var columns = @[Column(name: ours, exact: ours)]
  if top.len > 0:
    for name in top.split(","):
      columns.add Column(name: name, policies: @[name])
  else:
    columns.add topRivals(3)
  var ids =
    if rounds == "0": episodeIds(extra)
    else: episodeIds(@["--rounds", rounds] & extra)
  var seen: seq[string]
  for id in ids:
    if id notin seen:
      seen.add id
      columns.tally(id)
  var
    report = ""
    html = ""
  var counts = ""
  for c, column in columns:
    counts.add &"{column.name} {column.seats}" &
      (if c < columns.high: ", " else: ".")
  let summary = &"{seen.len} games (" &
    (if rounds == "0": "" else: &"last {rounds} league rounds") &
    (if extra.len > 0: " plus " & extra.join(" ") else: "") &
    &"). Seats per column: {counts}"
  report.add &"# Who Cried Wolf policy stats\n\n{summary}\n\n"
  report.add "Gap compares us with the rivals' average: LOW below 0.67x, " &
    "HIGH above 1.5x.\n"
  html.add """<!doctype html><html><head><meta charset="utf-8">
<title>Who Cried Wolf stats</title>
<style>
:root{--bg:#fbfaf8;--fg:#24292f;--muted:#6e7781;--line:#e4e1dc;--head:#f1eee9;--miss:#fbe9e7;--missline:#c0392b}
@media (prefers-color-scheme: dark){:root{--bg:#16181b;--fg:#e6e6e6;--muted:#9aa0a6;--line:#2c2f33;--head:#1f2226;--miss:#3a2224;--missline:#e06c5f}}
body{background:var(--bg);color:var(--fg);font:14px/1.45 -apple-system,system-ui,sans-serif;margin:24px auto;max-width:1040px;padding:0 16px}
h1{font-size:22px;margin:0 0 4px}h2{font-size:15px;margin:28px 0 8px;color:var(--muted);font-weight:600;text-transform:uppercase;letter-spacing:.04em}
p{color:var(--muted);margin:4px 0}
.scroll{overflow-x:auto}
table{border-collapse:collapse;width:100%;font-variant-numeric:tabular-nums}
th,td{padding:5px 10px;border-bottom:1px solid var(--line);text-align:right}
th:first-child,td:first-child{text-align:left}
th{background:var(--head);font-weight:600}
td.ours,th.ours{font-weight:600}
td small{color:var(--muted);display:block;font-weight:400}
tr.miss td{background:var(--miss)}tr.miss td:first-child{box-shadow:inset 3px 0 0 var(--missline)}
td.gap{color:var(--missline);font-weight:600;white-space:nowrap}
</style></head><body><h1>Who Cried Wolf policy stats</h1>"""
  html.add &"<p>{summary}</p><p>Rows in red: {ours} is out of line with " &
    "the rivals' average (below 0.67x or above 1.5x).</p>"

  proc section(title: string, keys: openArray[(string, string)]) =
    report.add &"\n## {title}\n\n| stat |"
    for column in columns:
      report.add &" {column.name} |"
    report.add " gap |\n|---|"
    for _ in columns:
      report.add "---:|"
    report.add "---|\n"
    html.add &"<h2>{title}</h2><div class=\"scroll\"><table><tr><th>stat</th>"
    for c, column in columns:
      html.add (if c == 0: "<th class=\"ours\">" else: "<th>") &
        column.name & "</th>"
    html.add "<th>gap</th></tr>"
    for (key, description) in keys:
      var
        rivals: seq[float]
        cells = ""
      report.add &"| {key} |"
      for c, column in columns:
        let
          value = column.value(key)
          text = if value.isNaN: "-" else: formatFloat(value, ffDecimal, 2)
        report.add " " & text & " |"
        cells.add (if c == 0: "<td class=\"ours\">" else: "<td>") & text &
          "</td>"
        if c > 0 and not value.isNaN:
          rivals.add value
      let gap = gapOf(columns[0].value(key), rivals)
      report.add &" {gap} |\n"
      html.add (if gap.len > 0: "<tr class=\"miss\">" else: "<tr>") &
        &"<td>{key}<small>{description}</small></td>{cells}" &
        &"<td class=\"gap\">{gap}</td></tr>"
    html.add "</table></div>"

  section("Direct control (ballots, speech, night actions)", Direct)
  section("Semi-indirect (how the table treats the seat)", Semi)
  section("Indirect (outcomes)", Indirect)
  html.add "</body></html>\n"
  echo report
  if outPath.len > 0:
    writeFile(outPath, report)
  if htmlPath.len > 0:
    writeFile(htmlPath, html)
    echo "html: ", htmlPath

main()
