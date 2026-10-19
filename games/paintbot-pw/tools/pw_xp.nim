## Creates hosted experience requests for Paintbot PW: our policy on eight
## seats against the live champion of each of the top three other players,
## once on the even (Red) seats and once on the odd (Blue) seats.
##
##   nim r tools/pw_xp.nim <tag> <policy:vN> [episodesPerRequest] [--rivals=a:vN,b:vN,c:vN]
##     [--coworld=cow_...]
##
## --rivals replaces the live top three with a fixed field (for example policies of similar
## skill, whose win rate against us can move). --coworld plays another engine version than
## the league's (for example a BASIC bot written for an older version).
##
## Writes eps/bodies/<tag>_<rival>_<side>.json, creates each request with
## the coworld CLI and appends "<xreq id> <side> <rival ref>" lines to
## eps/<tag>.txt for pw_score.

import
  std/[algorithm, httpclient, json, os, osproc, sequtils, strformat, strutils]

const
  Dash = "https://softmaxdash-nginx.tail0f4a29.ts.net/league/paintbot.json"
  Coworld = "cow_55019d36-0ec1-46ce-a51f-3545590624de"
  Variant = "1v1"
  Seats = 16
  Ours = ["Andre von Auto", "Andre von Houck"]

proc cli(): string =
  ## Returns the coworld CLI command backed by the stable metta checkout.
  "uvx --from " & quoteShell(getHomeDir() / "p/metta-coworld-cli/packages/coworld[auth]") &
    " coworld"

proc topThree(league: JsonNode): seq[(string, string)] =
  ## Returns (player, policy ref) for the three best rated other players.
  var champions: seq[(string, string)]
  for s in league["allPolicies"]:
    if s["champion"].getBool and s["status"].getStr == "competing":
      champions.add((
        s["player"].getStr,
        s["policy"].getStr & ":v" & $s["version"].getInt
      ))
  var rated = league["ratings"].getElems()
  rated.sort(proc(a, b: JsonNode): int = cmp(a["rank"].getInt, b["rank"].getInt))
  for r in rated:
    let player = r["player"].getStr
    if player in Ours:
      continue
    for (p, policyRef) in champions:
      if p == player and not result.anyIt(it[0] == player):
        result.add((player, policyRef))
    if result.len == 3:
      break

proc coworldId(): string =
  ## Returns --coworld's id, or the league's coworld without it.
  result = Coworld
  for i in 1 .. paramCount():
    if paramStr(i).startsWith("--coworld="):
      result = paramStr(i)["--coworld=".len .. ^1]

proc body(candidate, rival, notes: string, episodes, ourParity: int): JsonNode =
  ## Builds one request body with our policy on the seats of one parity.
  var roster = newJArray()
  for slot in 0 ..< Seats:
    let policyRef =
      if slot mod 2 == ourParity:
        candidate
      else:
        rival
    roster.add %*{"slot": slot, "player": {"policy_ref": policyRef}}
  %*{
    "target": {"coworld_id": coworldId(), "variant_id": Variant},
    "roster": roster,
    "num_episodes": episodes,
    "execution_backend": "k8s",
    "notes": notes
  }

proc create(path: string): string =
  ## Creates one request, retrying on refusals, and returns its id.
  for attempt in 0 ..< 6:
    let (output, code) = execCmdEx(
      cli() & " xp-request create " & quoteShell(path),
      options = {poUsePath, poStdErrToStdOut, poEvalCommand}
    )
    for word in output.splitWhitespace:
      if word.startsWith("xreq_"):
        return word.strip(chars = {',', '.', '"', '\''})
    echo "create failed (", code, "): ", output.strip
    sleep(60_000)
  quit("pw_xp: could not create " & path, 1)

proc rivalsFrom(): seq[(string, string)] =
  ## Returns the --rivals field as (label, policy ref) pairs, empty when absent.
  for i in 1 .. paramCount():
    let argument = paramStr(i)
    if argument.startsWith("--rivals="):
      for policyRef in argument["--rivals=".len .. ^1].split(','):
        result.add((policyRef, policyRef))

proc main() =
  if paramCount() < 2:
    quit("usage: pw_xp <tag> <policy:vN> [episodes]", 2)
  let
    tag = paramStr(1)
    candidate = paramStr(2)
    episodes =
      if paramCount() >= 3 and not paramStr(3).startsWith("--"):
        parseInt(paramStr(3))
      else:
        10
    league = parseJson(newHttpClient(timeout = 60_000).getContent(Dash))
    fixed = rivalsFrom()
    rivals =
      if fixed.len > 0:
        fixed
      else:
        topThree(league)
  createDir("eps/bodies")
  let listPath = "eps" / tag & ".txt"
  var list = open(listPath, fmAppend)
  for (player, rival) in rivals:
    for parity in 0 .. 1:
      let
        side =
          if parity == 0:
            "red"
          else:
            "blue"
        name = rival.split(':')[0]
        path = "eps/bodies" / &"{tag}_{name}_{side}.json"
        notes = &"{candidate} vs {player} {rival} ({side}) {tag}"
      writeFile(path, pretty(body(candidate, rival, notes, episodes, parity)))
      let id = create(path)
      echo id, " ", side, " ", rival
      list.writeLine(&"{id} {side} {rival}")
      list.flushFile()
  list.close()

main()
