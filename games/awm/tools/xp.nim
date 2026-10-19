## Hosted AWM experience requests against one live champion per other player.
##
##   xp body POLICY:vN TAG [EPISODES]   write eps/request_TAG.json
##   xp rings POLICY:vN TAG EPISODES    league-like pinned rings, TAG_rK
##   xp create TAG                      create it, save eps/created_TAG.json
##   xp get TAG                         save eps/status_TAG.json and score it
##   xp compare A1,A2 B1,B2             Fisher test: B's wins beat A's
##   xp totals PREFIX                   pooled wins over status_PREFIX*
##
## Requests seat our policy first and the other players' champions in
## rating order, as every earlier AWM control did.

import
  std/[algorithm, httpclient, json, math, os, osproc, strformat, strutils, tables]

const
  League = "league_ad6dc809-4696-46f5-99a5-fc2b1c58d082"
  Dash = "https://softmaxdash-nginx.tail0f4a29.ts.net/league/" &
    "archers-warriors-mages.json"
  Player = "Andre von Auto"
  Filler = "Andre von Houck filler"
  FillerPolicy = "AWM Baseline Filler:v1"
  BaselinePolicy = "AWM Baseline:v1"

let eps = currentSourcePath().parentDir / "../eps"

proc cli(arguments: string): string =
  ## Runs the stable coworld CLI and returns its output, quitting on failure.
  let (output, code) = execCmdEx(
    "uvx --from " &
      quoteShell(getHomeDir() / "p/metta-coworld-cli/packages/coworld[auth]") &
      " coworld " & arguments,
    options = {poUsePath, poStdErrToStdOut, poEvalCommand}
  )
  if code != 0:
    quit("xp: coworld " & arguments & " failed:\n" & output, 1)
  output

proc jsonOf(output: string): JsonNode =
  ## Parses the JSON object in CLI output, skipping any leading log lines.
  let start = output.find('{')
  if start < 0:
    quit("xp: no JSON in CLI output:\n" & output, 1)
  parseJson(output[start .. ^1])

proc champions(): seq[tuple[player, policy: string]] =
  ## One live champion per other player, in rating order.
  let client = newHttpClient(timeout = 60_000)
  defer:
    client.close()
  let dash = parseJson(client.getContent(Dash))
  for rating in dash["ratings"]:
    let name = rating["player"].getStr
    if name == Player:
      continue
    for standing in dash["standings"]:
      if standing["player"].getStr == name and
          standing["champion"].getBool and
          standing["status"].getStr == "competing":
        result.add (name, standing["policy"].getStr & ":v" &
          $standing["version"].getInt)
        break

proc rings(policy, tag: string, episodes: int) =
  ## Writes one request per ring order of the opponents, seats pinned: ours
  ## in seat 0, our next player in seat 1 and our attacker in the last seat,
  ## so every opponent takes turns attacking us as in league rounds. Like
  ## league rounds, the league's filler takes a fifth seat. Orders that only
  ## swap two policies with the same source are the same game and are
  ## written once. AWM_OUR_SLOTS (for example 0,1,2,3,4) repeats every
  ## order with our seat moved, as the league shuffles seats.
  var others: seq[tuple[player, policy: string]]
  if getEnv("AWM_RING_OPPONENTS").len > 0:
    for policy in getEnv("AWM_RING_OPPONENTS").split(','):
      others.add (policy.split(':')[0], policy)
  else:
    others = champions()
  let filler = if getEnv("AWM_FILLER").len > 0: getEnv("AWM_FILLER") else: FillerPolicy
  while others.len < 4:
    others.add (Filler, filler)
  var orders: seq[seq[int]]
  proc permute(prefix, rest: seq[int]) =
    if rest.len == 0:
      orders.add prefix
    for k in 0 ..< rest.len:
      var remaining = rest
      remaining.delete(k)
      permute(prefix & @[rest[k]], remaining)
  var all: seq[int]
  for i in 0 ..< others.len:
    all.add i
  permute(@[], all)
  proc sameCode(policy: string): string =
    ## Maps a policy to its source: fillers share one, and AWM_SAME_CODE
    ## lists a=b,c=d groups of identical uploads.
    if policy in [FillerPolicy, BaselinePolicy, filler]:
      return "baseline"
    result = policy
    for group in getEnv("AWM_SAME_CODE").split(','):
      let members = group.split('=')
      if policy in members:
        return members[0]
  var seen: seq[seq[string]]
  var unique: seq[seq[int]]
  for order in orders:
    var key: seq[string]
    for index in order:
      key.add sameCode(others[index].policy)
    if key notin seen:
      seen.add key
      unique.add order
  orders = unique
  var slots = @[0]
  if getEnv("AWM_OUR_SLOTS").len > 0:
    slots = @[]
    for s in getEnv("AWM_OUR_SLOTS").split(','):
      slots.add parseInt(s)
  var r = 0
  for order in orders:
    for ourSlot in slots:
      let seats = order.len + 1
      var roster = %*[{"slot": ourSlot, "player": {"policy_ref": policy}}]
      var ring = policy
      for seat, index in order:
        roster.add %*{"slot": (ourSlot + seat + 1) mod seats,
          "player": {"policy_ref": others[index].policy}}
        ring.add " -> " & others[index].policy
      let request = %*{
        "idempotency_key": "awm-ring-" & policy & "-" & tag & "-r" & $r,
        "target": {"league_id": League},
        "num_episodes": episodes,
        "roster": roster,
        "notes": "AWM " & policy & " vs one live champion per other " &
          "player, seats pinned as ring " & ring & " -> back to us, " &
          "ours in seat " & $ourSlot & "."
      }
      let path = eps / "request_" & tag & "_r" & $r & ".json"
      writeFile(path, request.pretty & "\n")
      echo tag, "_r", r, ": seat ", ourSlot, " ", ring
      inc r

proc body(policy, tag: string, episodes: int) =
  ## Writes a request seating our policy and every other live champion.
  let client = newHttpClient(timeout = 60_000)
  defer:
    client.close()
  let dash = parseJson(client.getContent(Dash))
  var
    roster = newJArray()
    opponents = newJArray()
    seen: seq[string]
  roster.add %*{"slot": -1, "player": {"policy_ref": policy}}
  for rating in dash["ratings"]:
    let name = rating["player"].getStr
    if name == Player or name in seen:
      continue
    for standing in dash["standings"]:
      if standing["player"].getStr == name and
          standing["champion"].getBool and
          standing["status"].getStr == "competing":
        let reference = standing["policy"].getStr & ":v" &
          $standing["version"].getInt
        roster.add %*{"slot": -1, "player": {"policy_ref": reference}}
        opponents.add %*{"player": name, "policy": reference}
        seen.add name
        break
  let request = %*{
    "idempotency_key": "awm-top3-" & policy & "-" & tag,
    "target": {"league_id": League},
    "num_episodes": episodes,
    "roster": roster,
    "notes": "AWM " & policy & " against one live champion per other " &
      "player, rotated seats, seeded classes. " & $opponents
  }
  let path = eps / "request_" & tag & ".json"
  writeFile(path, request.pretty & "\n")
  echo path, ": ", policy, " vs ", opponents

proc create(tag: string) =
  ## Creates the saved request and records the returned request.
  let
    output = cli("xp-request create " &
      quoteShell(eps / "request_" & tag & ".json") & " --json")
    node = jsonOf(output)
  writeFile(eps / "created_" & tag & ".json", node.pretty & "\n")
  echo tag, ": ", node["id"].getStr

proc score(path: string): tuple[label: string, wins, games: int] =
  ## Counts our policy's wins over completed episodes of one status file.
  let node = parseJson(readFile(path))
  for episode in node["episodes"]:
    if episode["status"].getStr != "completed":
      continue
    var ours = ""
    for p in episode["participants"]:
      if p["player_name"].getStr == Player:
        ours = p["policy_version_id"].getStr
        result.label = p["label"].getStr
    inc result.games
    for s in episode["scores"]:
      if s["policy_version_id"].getStr == ours and s["score"].getFloat > 0:
        inc result.wins

proc get(tag: string) =
  ## Saves the latest status and prints per-policy wins.
  let id = parseJson(readFile(eps / "created_" & tag & ".json"))["id"].getStr
  let node = jsonOf(cli("xp-request get " & id & " --json"))
  let path = eps / "status_" & tag & ".json"
  writeFile(path, node.pretty & "\n")
  var
    wins: seq[(string, int)]
    completed = 0
  for episode in node["episodes"]:
    if episode["status"].getStr != "completed":
      continue
    inc completed
    for p in episode["participants"]:
      for s in episode["scores"]:
        if s["policy_version_id"].getStr == p["policy_version_id"].getStr and
            s["score"].getFloat > 0:
          var found = false
          for w in wins.mitems:
            if w[0] == p["label"].getStr:
              inc w[1]
              found = true
          if not found:
            wins.add (p["label"].getStr, 1)
  var attackers: Table[string, (int, int)]
  for episode in node["episodes"]:
    if episode["status"].getStr != "completed":
      continue
    var labels: seq[(int, string, string)]
    for p in episode["participants"]:
      labels.add (p["position"].getInt, p["label"].getStr,
        p["policy_version_id"].getStr)
    labels.sort(proc (a, b: (int, string, string)): int = cmp(a[0], b[0]))
    var ours = -1
    for i, l in labels:
      for p in episode["participants"]:
        if p["position"].getInt == l[0] and p["player_name"].getStr == Player:
          ours = i
    if ours < 0:
      continue
    let attacker = labels[(ours - 1 + labels.len) mod labels.len][1]
    var won = 0
    for sc in episode["scores"]:
      if sc["policy_version_id"].getStr == labels[ours][2] and
          sc["score"].getFloat > 0:
        won = 1
    let previous = attackers.getOrDefault(attacker)
    attackers[attacker] = (previous[0] + won, previous[1] + 1)
  echo tag, " ", id, " ", node["status"].getStr, " ", node["coworld_version"].getStr,
    " completed ", completed, "/", node["episode_count"].getInt,
    " failed ", node["failed_count"].getInt
  for (label, count) in wins:
    echo "  ", label, " ", count
  for attacker, (won, games) in attackers:
    echo "  our wins with ", attacker, " attacking us: ", won, "/", games

proc logChoose(n, k: int): float =
  ## Natural log of n choose k.
  lgamma((n + 1).float) - lgamma((k + 1).float) - lgamma((n - k + 1).float)

proc fisher(winsA, gamesA, winsB, gamesB: int): float =
  ## One-sided Fisher exact p-value that B's win rate exceeds A's.
  let
    total = winsA + winsB
    games = gamesA + gamesB
    denominator = logChoose(games, total)
  for k in winsB .. min(gamesB, total):
    if total - k > gamesA:
      continue
    result += exp(logChoose(gamesB, k) + logChoose(gamesA, total - k) -
      denominator)

proc arm(tags: string): tuple[label: string, wins, games: int] =
  ## Pools comma-separated status tags of one policy.
  for tag in tags.split(','):
    let s = score(eps / "status_" & tag & ".json")
    if result.label.len > 0 and s.label != result.label:
      quit("xp: arm mixes " & result.label & " and " & s.label, 1)
    result.label = s.label
    result.wins += s.wins
    result.games += s.games

proc totals(prefix: string) =
  ## Pools every saved status whose tag starts with PREFIX: each policy's
  ## wins, and ours by the seat that attacked us.
  var
    wins: CountTable[string]
    byAttacker, attackerGames: CountTable[string]
    games = 0
  for path in walkFiles(eps / "status_" & prefix & "*.json"):
    let node = parseJson(readFile(path))
    for episode in node["episodes"]:
      if episode["status"].getStr != "completed":
        continue
      inc games
      var seats: seq[(int, string, string, string)]
      for p in episode["participants"]:
        seats.add (p["position"].getInt, p["label"].getStr,
          p["policy_version_id"].getStr, p["player_name"].getStr)
      seats.sort(proc (a, b: (int, string, string, string)): int =
        cmp(a[0], b[0]))
      var winner = ""
      for sc in episode["scores"]:
        if sc["score"].getFloat > 0:
          for seat in seats:
            if seat[2] == sc["policy_version_id"].getStr:
              winner = seat[1]
      if winner.len > 0:
        wins.inc winner
      for i, seat in seats:
        if seat[3] == Player:
          let attacker = seats[(i - 1 + seats.len) mod seats.len][1]
          attackerGames.inc attacker
          if winner == seat[1]:
            byAttacker.inc attacker
  echo prefix, ": ", games, " games"
  wins.sort()
  for label, n in wins:
    echo &"  {label}: {n}/{games} ({100.0 * n.float / max(1, games).float:.1f}%)"
  for attacker, n in attackerGames:
    echo &"  our wins with {attacker} attacking us: {byAttacker[attacker]}/{n}"

proc main() =
  ## Dispatches one subcommand.
  if paramCount() < 2:
    quit("Usage: xp body|create|get|compare ...", 1)
  case paramStr(1)
  of "body":
    let episodes = if paramCount() >= 4: parseInt(paramStr(4)) else: 100
    body(paramStr(2), paramStr(3), episodes)
  of "totals":
    totals(paramStr(2))
  of "rings":
    rings(paramStr(2), paramStr(3), parseInt(paramStr(4)))
  of "create":
    for k in 2 .. paramCount():
      create(paramStr(k))
  of "get":
    for k in 2 .. paramCount():
      get(paramStr(k))
  of "compare":
    let
      a = arm(paramStr(2))
      b = arm(paramStr(3))
      p = fisher(a.wins, a.games, b.wins, b.games)
    echo &"{a.label} {a.wins}/{a.games} " &
      &"({100.0 * a.wins.float / max(1, a.games).float:.1f}%) vs " &
      &"{b.label} {b.wins}/{b.games} " &
      &"({100.0 * b.wins.float / max(1, b.games).float:.1f}%), " &
      &"one-sided Fisher p {p:.4f}"
  else:
    quit("xp: unknown command " & paramStr(1), 1)

main()
