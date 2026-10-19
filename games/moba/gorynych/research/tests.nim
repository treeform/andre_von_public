## Format validation and tally checks for the MOBA replay extractor.

import std/[json, strutils]
import replays, tallies

proc sampleHeader(ticks: int): JsonNode =
  ## Builds a minimal valid v1 header.
  result = %*{
    "format_version": 1,
    "sim_wasm_sha256": "ab".repeat(32),
    "config": {
      "seed": 77,
      "heroes_per_seat": 5,
      "players": [{"name": "alpha"}, {"name": "beta"}]
    },
    "result": {
      "winner": 0,
      "end_reason": "ancient",
      "final_tick": ticks
    },
    "tick_count": ticks
  }

proc sampleBody(ticks: int, fill: array[6, uint8]): string =
  ## Packs ticks copies of the same 10x6 action matrix.
  result = newString(ticks * BytesPerTick)
  var offset = 0
  for tick in 0 ..< ticks:
    for pid in 0 ..< NumHeroes:
      for col in 0 ..< ActionsPerHero:
        result[offset] = char(fill[col])
        inc offset

echo "Testing pack/parse round trip"
let
  noop = [3'u8, 3, 0, 0, 0, 0]
  packed = packReplay(sampleHeader(3), sampleBody(3, noop))
  parsed = parseReplay(packed)
doAssert packed[0 .. 3] == Magic
doAssert packed[4].uint8 == uint8(FormatVersion)
doAssert parsed.tickCount == 3
doAssert parsed.heroesPerSeat() == 5
doAssert parsed.playerNames() == @["alpha", "beta"]
doAssert parsed.seedOf() == 77
doAssert isNoop(parsed.rowAt(1, 4))
doAssert parsed.actionAt(2, 9, 0) == 3'u8

echo "Testing empty episode"
let empty = parseReplay(packReplay(sampleHeader(0), ""))
doAssert empty.tickCount == 0
doAssert empty.body.len == 0

echo "Testing action range rejection"
var bad = sampleBody(1, noop)
bad[2] = char(3)  # Target-filter high is 3 exclusive.
try:
  discard packReplay(sampleHeader(1), bad)
  doAssert false, "out of range target should fail"
except ReplayError:
  discard

echo "Testing bad magic"
try:
  discard parseReplay("NOPE" & packed[4 .. ^1])
  doAssert false, "bad magic should fail"
except ReplayError as error:
  doAssert "magic" in error.msg

echo "Testing bad version byte"
var badVer = packed
badVer[4] = char(9)
try:
  discard parseReplay(badVer)
  doAssert false, "bad version should fail"
except ReplayError as error:
  doAssert "version" in error.msg

echo "Testing truncated header"
try:
  discard parseReplay("MOBA" & char(1) & "\xff\xff\xff\x00rest")
  doAssert false, "truncated header should fail"
except ReplayError:
  discard

echo "Testing truncated body"
try:
  discard parseReplay(packed[0 .. ^10])
  doAssert false, "truncated body should fail"
except ReplayError:
  discard

echo "Testing missing tick_count"
var noTicks = sampleHeader(1)
noTicks.delete("tick_count")
try:
  discard packReplay(noTicks, sampleBody(1, noop))
  doAssert false, "missing tick_count should fail"
except ReplayError:
  discard

echo "Testing invalid header JSON"
var junk = packed
for i in PrefixLen .. PrefixLen + 3:
  junk[i] = 'x'
try:
  discard parseReplay(junk)
  doAssert false, "invalid JSON should fail"
except ReplayError as error:
  doAssert "JSON" in error.msg

echo "Testing header format_version mismatch"
var mismatch = sampleHeader(1)
mismatch["format_version"] = %2
let mismatchBytes = packReplay(mismatch, sampleBody(1, noop))
try:
  discard parseReplay(mismatchBytes)
  doAssert false, "format_version mismatch should fail"
except ReplayError as error:
  doAssert "format_version" in error.msg

echo "Testing body length mismatch"
try:
  var header = sampleHeader(2)
  discard packReplay(header, sampleBody(1, noop))
  doAssert false, "length mismatch should fail"
except ReplayError:
  discard

echo "Testing direction classify"
doAssert classify(3, 3) == Hold
doAssert classify(0, 3) == North
doAssert classify(6, 3) == South
doAssert classify(3, 6) == East
doAssert classify(3, 0) == West
doAssert classify(0, 6) == Northeast
doAssert classify(0, 0) == Northwest
doAssert classify(6, 6) == Southeast
doAssert classify(6, 0) == Southwest

echo "Testing tallies on scripted-like push"
var push = [6'u8, 6, 2, 1, 0, 0]  # Southeast, heroes+towers, Q.
let
  pushReplay = parseReplay(
    packReplay(sampleHeader(4), sampleBody(4, push))
  )
  tally = tallyReplay(pushReplay)
doAssert tally.ticks == 4
doAssert tally.positionsRecoverable == false
doAssert tally.winner == "radiant"
doAssert tally.heroes[0].skillQ == 4
doAssert tally.heroes[0].skillW == 0
doAssert tally.heroes[0].targetHeroTower == 4
doAssert tally.heroes[0].noops == 0
doAssert tally.heroes[0].discreteVel == 4
doAssert tally.heroes[0].primaryDirection == "southeast"
doAssert tally.heroes[0].assignedLane == "bot"
doAssert tally.teamStack[0] > 0.99
doAssert isNoop(NoopAction)

echo "Testing no-op tally"
let
  noopReplay = parseReplay(
    packReplay(sampleHeader(5), sampleBody(5, noop))
  )
  noopTally = tallyReplay(noopReplay)
doAssert noopTally.heroes[7].noops == 5
doAssert noopTally.heroes[7].maxNoopRun == 5
doAssert noopTally.heroes[7].holds == 5
doAssert noopTally.heroes[7].primaryDirection == "hold"

echo "All replay extractor tests passed"
