## Launches hosted XP for one candidate against every field opponent.
##
## nim r -d:release --hints:off tools/mfield.nim <candidate> <episodes>
##   <out.txt> <opponent> [<opponent> ...]
##
## Each opponent gets two arms (candidate blue, candidate red) of
## <episodes> games, four seats each. Request ids are appended to <out.txt>
## as "opponent side xreq" lines for tools/mxp.nim.

import
  std/[json, os, osproc, strutils]

const
  LeagueId = "league_5473de87-a7cc-451f-9cf1-6e1a769a89a3"

proc create(body: JsonNode): string =
  ## Creates one request, retrying when the pending-request cap answers 429.
  let path = getTempDir() / "mfield_body.json"
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
    if output.contains("(409)"):
      # A used idempotency key never clears; retrying cannot help.
      echo "create refused: ", output.strip.splitLines[^1]
      return ""
    echo "create failed (attempt ", attempt + 1, "), retrying: ",
      output.strip.splitLines[^1]
    sleep(60_000)
  ""

proc main() =
  ## Creates both seat arms for every opponent.
  let args = commandLineParams()
  if args.len < 4:
    quit("Usage: mfield <candidate> <episodes> <out.txt> <opponent>...", 2)
  let
    candidate = args[0]
    episodes = args[1].parseInt
    output = args[2]
  var log = open(output, fmAppend)
  defer:
    log.close()
  for opponent in args[3 .. ^1]:
    for side in ["blue", "red"]:
      var roster = newJArray()
      for slot in 0 ..< 8:
        let ours = (slot < 4) == (side == "blue")
        roster.add %*{"slot": slot, "player": {"policy_ref":
          (if ours: candidate else: opponent)}}
      let body = %*{
        "idempotency_key": "mindustry-" & candidate & "-" & opponent & "-" &
          side & "-" & output.extractFilename,
        "target": {"league_id": LeagueId},
        "num_episodes": episodes,
        "roster": roster,
        "notes": candidate & " (" & side & ", four seats) vs " & opponent &
          " (four seats): field check for the next Polkan champion."
      }
      let id = create(body)
      echo opponent, " ", side, " ", id
      log.writeLine(opponent & " " & side & " " & id)
      log.flushFile()

main()
