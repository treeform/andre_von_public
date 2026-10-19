## Builds hosted experience-request bodies for Gods of the Arena:
## our candidate on one side (five seats) against the live champions of
## the top three other players on the other side, and the mirror.
##
##   nim r games/gods-of-the-arena/tools/gota_xp.nim khors:v3 [episodes]
##
## Reads the dash league JSON for standings and champions, the league's
## bound coworld from the observatory (via the coworld CLI's league JSON
## saved by the caller is not needed: the dash carries the coworld id in
## the league record when present, else pass --coworld cow_...).
## Writes eps/bodies/<tag>_red.json and <tag>_blue.json and prints them.

import std/[httpclient, json, os, strutils, strformat, algorithm, sequtils]

const
  Dash = "https://softmaxdash-nginx.tail0f4a29.ts.net/league/gods-of-the-arena.json"
  Seats = 10
  Ours = ["Andre von Auto", "Andre von Houck"]

proc topThree(league: JsonNode): seq[(string, string)] =
  ## Returns (player, policy_ref) for the three best-rated other players
  ## that have an active champion.
  var champions: seq[(string, string)]
  for s in league["standings"]:
    if s["champion"].getBool and s["status"].getStr == "competing":
      champions.add((s["player"].getStr, s["policy"].getStr & ":v" & $s["version"].getInt))
  var rated = league["ratings"].getElems()
  rated.sort(proc(a, b: JsonNode): int = cmp(a["rank"].getInt, b["rank"].getInt))
  for r in rated:
    let player = r["player"].getStr
    if player in Ours: continue
    for (p, policyRef) in champions:
      if p == player and not result.anyIt(it[0] == player):
        result.add((player, policyRef))
    if result.len == 3: break

proc body(coworld, candidate, tag: string, episodes: int,
          rivals: seq[(string, string)], ourSide: int): JsonNode =
  var roster = newJArray()
  for slot in 0 ..< Seats:
    let team = slot div 5
    var policyRef: string
    if team == ourSide:
      policyRef = candidate
    else:
      policyRef = rivals[(slot mod 5) mod rivals.len][1]
    roster.add %*{"slot": slot, "player": {"policy_ref": policyRef}}
  %*{"coworld_id": coworld, "num_episodes": episodes,
     "notes": &"{candidate} vs {(if rivals.len == 1: rivals[0][1] else: \"top3 (\" & rivals.mapIt(it[0]).join(\", \") & \")\")} {tag}",
     "roster": roster}

proc leagueBody(coworld, candidate: string, slot, episodes: int,
                field: seq[string]): JsonNode =
  ## League rounds seat one hero per player: the candidate takes one slot and
  ## nine distinct rivals fill the rest, rotated by slot so every body has a
  ## different neighbourhood. Score only the candidate's hero afterwards.
  ## Field lines starting with '*' are always present (the live top players):
  ## star i sits at offset 1 + ((2i + 3*slot) mod 9) from the candidate, so
  ## across the ten bodies each star is our teammate 4-5 times, visits 8
  ## distinct seats and holds a team-first (first draft pick) seat 1-3 times.
  ## The old adjacent layout made ~4 of 5 stars our teammates; an odd-offset
  ## try pinned one star to the team-first seat in every body. The rest
  ## rotate through the remaining seats.
  var always: seq[string]
  var rotating: seq[string]
  for policyRef in field:
    if policyRef.startsWith("*"):
      always.add policyRef[1 .. ^1]
    else:
      rotating.add policyRef
  var seats = newSeq[string](Seats)
  seats[slot] = candidate
  for i, policyRef in always:
    seats[(slot + 1 + (2 * i + 3 * slot) mod 9) mod Seats] = policyRef
  var seat = slot + 1
  var next = slot * 3
  for k in 0 ..< Seats:
    if seats[(seat + k) mod Seats].len == 0:
      seats[(seat + k) mod Seats] = rotating[next mod rotating.len]
      inc next
  var roster = newJArray()
  for seat in 0 ..< Seats:
    roster.add %*{"slot": seat, "player": {"policy_ref": seats[seat]}}
  %*{"coworld_id": coworld, "num_episodes": episodes,
     "notes": &"{candidate} league-style slot {slot}",
     "roster": roster}

when isMainModule:
  if paramCount() < 1: quit("usage: gota_xp.nim <candidate name:vN> [episodes] [--coworld cow_...] [--league field.txt] [--rivals a:vN,b:vN,c:vN]")
  let candidate = paramStr(1)
  var episodes = 12
  var coworld = ""
  var only = ""
  var fieldPath = ""
  var named = ""
  var i = 2
  while i <= paramCount():
    if paramStr(i) == "--coworld": coworld = paramStr(i + 1); inc i
    elif paramStr(i) == "--only": only = paramStr(i + 1); inc i
    elif paramStr(i) == "--league": fieldPath = paramStr(i + 1); inc i
    elif paramStr(i) == "--rivals": named = paramStr(i + 1); inc i
    else: episodes = parseInt(paramStr(i))
    inc i
  if fieldPath.len > 0:
    ## One body per slot; the field file lists one policy_ref per line.
    doAssert coworld.len > 0, "pass --coworld cow_... with --league"
    var field: seq[string]
    for line in readFile(fieldPath).splitLines:
      let policyRef = line.strip
      if policyRef.len > 0 and not policyRef.startsWith(candidate.split(':')[0] & ":"):
        field.add policyRef
    doAssert field.len >= 9, "the league field needs at least nine rivals"
    let dir = "games/gods-of-the-arena/eps/bodies"
    createDir(dir)
    let stem = candidate.replace(":", "_")
    for slot in 0 ..< Seats:
      let path = dir / &"{stem}_league_s{slot}.json"
      writeFile(path, leagueBody(coworld, candidate, slot, episodes, field).pretty)
      echo path
    quit(0)
  let client = newHttpClient()
  let league = parseJson(client.getContent(Dash))
  if coworld.len == 0:
    coworld = league["league"]{"coworldId"}.getStr("")
  if coworld.len == 0: quit("pass --coworld cow_...: the dash record has no coworld id")
  var rivals = topThree(league)
  if only.len > 0:
    ## One named rival fills every opposing seat (a head-to-head arm).
    rivals = @[(only.split(':')[0], only)]
  if named.len > 0:
    ## Comma-separated policy refs replace the dash's top three.
    rivals = @[]
    for policyRef in named.split(','):
      rivals.add((policyRef.split(':')[0], policyRef))
  doAssert rivals.len >= 1, "no rated rivals with champions"
  let dir = "games/gods-of-the-arena/eps/bodies"
  createDir(dir)
  var stem = candidate.replace(":", "_")
  if named.len > 0: stem &= "_vs_named"
  if only.len > 0: stem &= "_vs_" & only.split(':')[0].replace("-", "_")[0 .. min(11, only.split(':')[0].len - 1)]
  for (side, name) in [(0, "red"), (1, "blue")]:
    let path = dir / &"{stem}_{name}.json"
    writeFile(path, body(coworld, candidate, name, episodes, rivals, side).pretty)
    echo path
  echo "rivals: ", rivals
