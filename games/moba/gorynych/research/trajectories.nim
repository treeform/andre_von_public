## Reconstruct one hosted MOBA replay through the pinned sim wasm.
## Usage: trajectories [replay.moba] [moba_sim.wasm]
## Default proof: evidence/replays/r3730-g4.moba (daveey vs richard).
## Never scores local games. Writes JSON only after an end-state match.

import
  std/[json, os, strutils],
  observations, reconstructs, replays, runtimes

const
  ResearchDir = currentSourcePath().parentDir
  EvidenceDir = ResearchDir / "evidence"
  DefaultReplay = EvidenceDir / "replays" / "r3730-g4.moba"

proc findWasm(explicit: string): string =
  ## Resolves the pinned sim wasm path.
  if explicit.len > 0:
    if not fileExists(explicit):
      raiseRecon("wasm not found: " & explicit)
    return explicit
  let env = getEnv("MOBA_SIM_WASM")
  if env.len > 0:
    if not fileExists(env):
      raiseRecon("MOBA_SIM_WASM not found: " & env)
    return env
  const Candidates = [
    EvidenceDir / "wasm" / "moba_sim.wasm",
    ResearchDir / ".." / ".." / ".." / ".." / "sims" / "moba" /
      "build" / "moba_sim.wasm",
    "/Users/me/p/andre_von_auto/sims/moba/build/moba_sim.wasm"
  ]
  for path in Candidates:
    if fileExists(path):
      return path
  raiseRecon(
    "pinned moba_sim.wasm not found. Place the exact hosted binary at " &
    EvidenceDir / "wasm" / "moba_sim.wasm" &
    " (sha256 " & ExpectedWasmSha & ")"
  )

proc pct(value: float): string =
  ## Formats a 0..1 rate as a percentage.
  formatFloat(value * 100.0, ffDecimal, 1) & "%"

proc printSummary(rec: Reconstruction, names: seq[string]) =
  ## Prints occupancy, tower, and assassin-E proof.
  echo "verified reconstruction of ", rec.replayPath
  echo "  wasm ", rec.wasmSha
  echo "  seed ", rec.seed, " ticks ", rec.ticks,
    " winner ", rec.simWinner, " digest ", rec.simDigest
  echo "  scoring_evidence=false"
  echo "opening window ", rec.openingWindow, " ticks"
  for team in 0 .. 1:
    let label =
      if team < names.len: names[team] else: TeamNames[team]
    echo "  ", TeamNames[team], " (", label, ") opening occupancy:"
    var sum = 0
    for i in 0 .. 4:
      sum += rec.teamOpening[team][i]
    for i, name in RegionNames:
      echo "    ", name, "=", pct(
        if sum == 0: 0.0 else: float(rec.teamOpening[team][i]) / float(sum)
      )
    echo "    four-plus same corridor=",
      pct(if rec.openingWindow == 0: 0.0
          else: float(rec.teamStackOpening[team]) / float(rec.openingWindow))
  echo "tower deaths ", rec.towerDeaths.len
  for event in rec.towerDeaths:
    echo "  tick ", event.tick, " pid ", event.pid, " ",
      roleName(event.pid), " tower ", event.towerIndex,
      " team ", event.towerTeam, " tier ", event.towerTier
  for pid in AssassinPids:
    let hero = rec.heroes[pid]
    let seat = if pid < 5: 0 else: 1
    let label = if seat < names.len: names[seat] else: teamName(pid)
    echo "assassin pid ", pid, " ", label,
      " flags=", hero.eFlags,
      " fires=", hero.eFires,
      " blocked=", hero.eBlocked,
      " lowHP=", hero.eOnRetreat,
      " fountain=", hero.eOnFountain
    echo "  in-range=", pct(if rec.ticks == 0: 0.0
        else: float(hero.inTowerRange) / float(rec.ticks)),
      " exposed=", pct(if rec.ticks == 0: 0.0
        else: float(hero.exposed) / float(rec.ticks)),
      " covered=", pct(if rec.ticks == 0: 0.0
        else: float(hero.covered) / float(rec.ticks))
  for pid in 0 ..< NumHeroes:
    let hero = rec.heroes[pid]
    echo "  pid ", pid, " ", hero.role,
      " assigned=", hero.assigned,
      " opening ",
      "top=", pct(if rec.openingWindow == 0: 0.0
        else: float(hero.opening[0]) / float(rec.openingWindow)),
      " mid=", pct(if rec.openingWindow == 0: 0.0
        else: float(hero.opening[1]) / float(rec.openingWindow)),
      " bot=", pct(if rec.openingWindow == 0: 0.0
        else: float(hero.opening[2]) / float(rec.openingWindow)),
      " fountain=", pct(if rec.openingWindow == 0: 0.0
        else: float(hero.opening[3]) / float(rec.openingWindow)),
      " jungle=", pct(if rec.openingWindow == 0: 0.0
        else: float(hero.opening[4]) / float(rec.openingWindow)),
      " exposed=", pct(if rec.ticks == 0: 0.0
        else: float(hero.exposed) / float(rec.ticks)),
      " covered=", pct(if rec.ticks == 0: 0.0
        else: float(hero.covered) / float(rec.ticks))

proc main() =
  ## Reconstructs one hosted replay and writes JSON evidence.
  let
    replayPath =
      if paramCount() >= 1: paramStr(1) else: DefaultReplay
    wasmPath =
      findWasm(if paramCount() >= 2: paramStr(2) else: "")
    outPath =
      if paramCount() >= 3: paramStr(3)
      else:
        EvidenceDir / "trajectories" /
          splitFile(replayPath).name & ".json"
  echo "replay ", replayPath
  echo "wasm ", wasmPath
  let rec = reconstruct(replayPath, wasmPath)
  let replay = parseReplay(readFile(replayPath))
  printSummary(rec, replay.playerNames())
  try:
    createDir(parentDir(outPath))
    writeFile(outPath, pretty(reconstructionJson(rec)))
  except CatchableError as error:
    raiseRecon("write " & outPath & ": " & error.msg)
  echo "wrote ", outPath

main()
