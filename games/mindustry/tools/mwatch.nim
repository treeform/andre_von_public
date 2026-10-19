## Waits for the Mindustry 4v4 league to change, then prints what changed.
##
## A change is a newly completed round, a new player or policy on the
## division ladder, or a new canonical coworld. Reads the platform through
## the coworld CLI (the dash caches pages). Run it in the background:
## nim r -d:release --hints:off tools/mwatch.nim [pollSeconds] [maxHours]

import
  std/[json, os, osproc, sets, strutils, times]

const
  LeagueId = "league_5473de87-a7cc-451f-9cf1-6e1a769a89a3"
  DivisionId = "div_456e790e-1a5a-40f3-a292-fc44f504fe7c"

type
  Snapshot = object
    round: int
    entries: HashSet[string]
    coworld: string
    board: string

proc cli(arguments: string): JsonNode =
  ## Runs one coworld CLI command and parses its JSON, or returns nil.
  let
    command = "uvx --from \"" & getHomeDir() /
      "p/metta-coworld-cli/packages/coworld[auth]\" coworld " & arguments
    (output, code) = execCmdEx(command,
      options = {poUsePath, poStdErrToStdOut, poEvalCommand})
  if code != 0:
    return nil
  var start = -1
  for i, c in output:
    if c in {'[', '{'}:
      start = i
      break
  if start < 0:
    return nil
  try:
    result = parseJson(output[start .. ^1])
  except CatchableError:
    result = nil

proc snapshot(): Snapshot =
  ## Captures the parts of the league that should trigger a reaction.
  result.round = -1
  let rounds = cli("rounds --league " & LeagueId & " --json --limit 5")
  if rounds != nil:
    for round in rounds["entries"]:
      if round["status"].getStr == "completed":
        result.round = max(result.round, round["round_number"].getInt)
  let ladder = cli("results " & DivisionId & " --json")
  if ladder != nil:
    for row in ladder:
      result.entries.incl row["player_name"].getStr & " " &
        row["policy_label"].getStr
      result.board.add $row["rank"].getInt & ". " &
        row["player_name"].getStr & " " & row["policy_label"].getStr &
        " MMR " & $row["score"].getFloat.int & "\n"
  let leagues = cli("leagues --json")
  if leagues != nil:
    for league in leagues:
      if league{"id"}.getStr == LeagueId:
        result.coworld = league{"game"}{"canonical_coworld_id"}.getStr

proc main() =
  ## Polls until something changes or the time budget runs out.
  let
    args = commandLineParams()
    pollSeconds = if args.len > 0: args[0].parseInt else: 600
    maxHours = if args.len > 1: args[1].parseFloat else: 8.0
    started = epochTime()
    first = snapshot()
  echo "watching from round ", first.round, " coworld ", first.coworld
  echo first.board
  while epochTime() - started < maxHours * 3600:
    sleep(pollSeconds * 1000)
    let now = snapshot()
    var changes: seq[string]
    if now.round > first.round:
      changes.add "round " & $now.round & " completed"
    if now.board.len > 0:
      for entry in now.entries - first.entries:
        changes.add "new ladder entry " & entry
    if now.coworld.len > 0 and first.coworld.len > 0 and
      now.coworld != first.coworld:
        changes.add "coworld " & first.coworld & " -> " & now.coworld
    if changes.len > 0:
      echo changes.join("\n")
      echo now.board
      return
  echo "no change within ", maxHours, " hours"

main()
