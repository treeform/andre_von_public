## Seat rosters for pw_fast replay directories.
##
## pw_fast saves eps/fast/<tag>/<rival>_vN_<side>_<seed>/games/NNN/replay.replay
## and one line per game in eps/fast/<tag>.tsv (rival, side, seed, ours,
## theirs, ticks, seconds). Game NNN of a batch used seed <seed> + NNN.

import
  std/[os, strutils, tables]

var outcomes = initTable[string, bool]()

proc loadOutcomes(table, tag: string) =
  ## Reads one tag's game results once.
  if (tag & "/") in outcomes:
    return
  outcomes[tag & "/"] = true
  if not fileExists(table):
    return
  for line in lines(table):
    let fields = line.split('\t')
    if fields.len >= 5:
      outcomes[tag & "/" & fields[0] & "/" & fields[1] & "/" & fields[2]] =
        parseFloat(fields[3]) > parseFloat(fields[4])

proc fastRoster*(path: string, split = false): seq[string] =
  ## Returns 16 seat labels for a pw_fast replay, or nothing for other paths.
  ## Our seats carry the tag, with " win" or " loss" when split is set.
  let parts = path.split(DirSep)
  if parts.len < 5 or parts[^3] != "games":
    return
  let batch = parts[^4].split('_')
  if batch.len != 4:
    return
  let
    tag = parts[^5]
    rival = batch[0] & ":" & batch[1]
    side = batch[2]
    seed = parseInt(batch[3]) + parseInt(parts[^2])
  var ours = tag
  if split:
    loadOutcomes(parts[0 ..< ^5].join($DirSep) / tag & ".tsv", tag)
    let key = tag & "/" & rival & "/" & side & "/" & $seed
    if key notin outcomes:
      return
    ours =
      if outcomes[key]:
        tag & " win"
      else:
        tag & " loss"
  for slot in 0 ..< 16:
    if (slot mod 2 == 0) == (side == "red"):
      result.add ours
    else:
      result.add rival
