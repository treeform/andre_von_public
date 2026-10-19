## Launches hosted XP that mirrors the league's mixed rosters.
##
## nim r -d:release --hints:off tools/mmixed.nim <candidate> <layouts>
##   <episodes> <out.txt> <rival> [<rival> ...]
##
## The league seats six entrants in eight slots with distinct teammates,
## so two entrants hold two seats on one team and everyone else holds one.
## Each layout deals the candidate and the rivals into the eight slots from
## a fixed random sequence, so two candidates run on identical layouts.
## Lines "layout side slots xreq" are appended to <out.txt>; score them with
## tools/mxp.nim (the candidate's seats decide its team's result). A leading
## --doubled always deals the candidate one of the two doubled seats, to test
## behaviour that only a second seat of ours changes.

import
  std/[json, os, osproc, random, strutils]

const
  LeagueId = "league_5473de87-a7cc-451f-9cf1-6e1a769a89a3"

proc create(body: JsonNode): string =
  ## Creates one request, retrying when the pending-request cap answers 429.
  let path = getTempDir() / "mmixed_body.json"
  writeFile(path, $body)
  let command = "uvx --from \"" & getHomeDir() /
    "p/metta-coworld-cli/packages/coworld[auth]\" coworld xp-request create " &
    quoteShell(path) & " --json"
  for attempt in 0 ..< 10:
    let (output, code) = execCmdEx(command,
      options = {poUsePath, poStdErrToStdOut, poEvalCommand})
    let start = output.find('{')
    if code == 0 and start >= 0:
      try:
        let id = parseJson(output[start .. ^1]){"id"}.getStr
        if id.len > 0:
          return id
      except CatchableError:
        discard
    echo "create failed (attempt ", attempt + 1, "), retrying: ",
      output.strip.splitLines[^1]
    sleep(60_000)
  ""

proc deal(rng: var Rand, entrants: seq[string], doubled: bool): seq[string] =
  ## Deals entrants into eight slots: two random entrants take a second
  ## seat on their own team, the rest one seat each, teams shuffled. The
  ## candidate comes first in entrants; doubled makes it one of the pair.
  doAssert entrants.len == 6, "the league layout needs six entrants"
  var order = entrants
  rng.shuffle(order)
  if doubled:
    let at = order.find(entrants[0])
    swap(order[at], order[rng.rand(1)])
  # The first two in the shuffled order are doubled.
  var
    blue: seq[string]
    red: seq[string]
  blue.add order[0]
  blue.add order[0]
  red.add order[1]
  red.add order[1]
  for i in 2 ..< 6:
    if blue.len < 4 and (red.len >= 4 or rng.rand(1) == 0):
      blue.add order[i]
    else:
      red.add order[i]
  rng.shuffle(blue)
  rng.shuffle(red)
  result = blue & red

proc main() =
  ## Creates one request per layout.
  var args = commandLineParams()
  let doubled = args.len > 0 and args[0] == "--doubled"
  if doubled:
    args.delete(0)
  if args.len < 9:
    quit("Usage: mmixed <candidate> <layouts> <episodes> <out.txt> " &
      "<rival> x5", 2)
  let
    candidate = args[0]
    layouts = args[1].parseInt
    episodes = args[2].parseInt
    output = args[3]
    rivals = args[4 .. ^1]
  var
    rng = initRand(20261007)
    log = open(output, fmAppend)
  defer:
    log.close()
  for layout in 0 ..< layouts:
    let slots = rng.deal(@[candidate] & rivals, doubled)
    var
      roster = newJArray()
      ours: seq[int]
    for slot, policy in slots:
      roster.add %*{"slot": slot, "player": {"policy_ref": policy}}
      if policy == candidate:
        ours.add slot
    let side = if ours[0] < 4: "blue" else: "red"
    let body = %*{
      "idempotency_key": "mindustry-mixed-" & candidate & "-" & $layout &
        "-" & output.extractFilename,
      "target": {"league_id": LeagueId},
      "num_episodes": episodes,
      "roster": roster,
      "notes": candidate & " in league-style mixed layout " & $layout &
        " (slots " & ours.join(",") & "): " & slots.join(" ")
    }
    let id = create(body)
    echo layout, " ", side, " ", ours.join(","), " ", id
    log.writeLine($layout & " " & side & " " & ours.join(",") & " " & id)
    log.flushFile()

main()
