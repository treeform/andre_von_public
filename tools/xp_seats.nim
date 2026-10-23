## Per-seat outcome summary for a hosted experience request, from the
## server's own episode results (no re-simulation, so it works on any
## game version). For each episode the coworld CLI returns per_seat
## kills/deaths/hooks_thrown/hooks_landed; this pools our policy's seats
## against the rest and prints per-seat-game means.
## Run: nim r --hints:off tools/xp_seats.nim <eps.json> <policy>
##   eps.json comes from tools/xp_fetch.nim (participants carry policy_name
##   and position).

import std/[json, os, osproc, strformat, strutils]

type Tally = object
  seats: int
  kills, deaths, thrown, landed: float
  score: float

proc add(t: var Tally, seat: JsonNode, score: float) =
  inc t.seats
  t.kills += seat{"kills"}.getFloat
  t.deaths += seat{"deaths"}.getFloat
  t.thrown += seat{"hooks_thrown"}.getFloat
  t.landed += seat{"hooks_landed"}.getFloat
  t.score += score

proc line(name: string, t: Tally): string =
  if t.seats == 0:
    return name & ": no seats"
  let n = t.seats.float
  &"{name}: seat-games {t.seats}  score {t.score / n:.3f}  kills {t.kills / n:.2f}  " &
    &"deaths {t.deaths / n:.2f}  K-D {(t.kills - t.deaths) / n:+.2f}  " &
    &"hooks {t.thrown / n:.1f}  landed {t.landed / n:.1f} ({100.0 * t.landed / max(t.thrown, 1.0):.0f}%)"

proc results(episodeId: string): JsonNode =
  let (output, code) = execCmdEx(
    "uvx --from " & quoteShell(getHomeDir() / "p/metta-coworld-cli/packages/coworld[auth]") &
    " coworld episode-results " & episodeId,
    options = {poUsePath, poStdErrToStdOut})
  let start = output.find('{')
  if code != 0 or start < 0:
    return nil
  try:
    parseJson(output[start .. ^1])
  except CatchableError:
    nil

proc main() =
  if paramCount() < 2:
    quit("usage: xp_seats <eps.json> <policy>", 2)
  let
    episodes = parseJson(readFile(paramStr(1)))
    policy = paramStr(2)
  var
    ours, field: Tally
    games = 0
  for episode in episodes:
    if episode{"status"}.getStr != "completed":
      continue
    var ourPositions: seq[int]
    for participant in episode{"participants"}:
      if participant{"policy_name"}.getStr == policy:
        ourPositions.add participant{"position"}.getInt
    var scores: array[8, float]
    for entry in episode{"participant_scores"}:
      let position = entry{"position"}.getInt
      if position >= 0 and position < 8:
        scores[position] = entry{"score"}.getFloat
    let result = results(episode{"id"}.getStr)
    if result.isNil:
      echo "no results for ", episode{"id"}.getStr
      continue
    inc games
    for seat in result{"per_seat"}:
      let slot = seat{"slot"}.getInt
      if slot in ourPositions:
        ours.add(seat, scores[min(slot, 7)])
      else:
        field.add(seat, scores[min(slot, 7)])
  echo games, " episodes"
  echo line("ours (" & policy & ")", ours)
  echo line("field", field)

main()
