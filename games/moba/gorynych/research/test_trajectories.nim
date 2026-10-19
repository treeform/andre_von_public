## Format and occupancy-logic tests for the reconstruction extractor.
## Wasm replay tests run only when the pinned binary is present.

import
  std/[json, os],
  observations, reconstructs, replays, runtimes

echo "Testing seed bit pattern"
doAssert seedBits(77) == 77'i32
doAssert seedBits(2672160491) == cast[int32](2672160491'u32)
doAssert seedBits(0x100000000'i64) == 0'i32

echo "Testing region classification of known cells"
doAssert classifyRegion(113, 12, 0) == FountainRegion
doAssert classifyRegion(15, 116, 1) == FountainRegion
doAssert classifyRegion(20, 18, 0) == TopRegion
doAssert classifyRegion(64, 64, 0) == MidRegion
doAssert classifyRegion(112, 80, 0) == BotRegion
doAssert assignedRegion(3) == TopRegion
doAssert assignedRegion(1) == MidRegion
doAssert assignedRegion(0) == BotRegion
doAssert assignedRegion(4) == BotRegion

echo "Testing tower cells and soak"
doAssert shoots(0)
doAssert not shoots(22)
doAssert not shoots(23)
let (ty, tx) = towerCell(0)
doAssert ty == 112
doAssert tx == 34
var view = HeroView(x: 34, y: 112, team: 1)
# Friendly dire creep one cell closer to the tower than the hero.
view.crop[(5 + 0) * 11 + (5 + 0)] = TowerTile
view.crop[(5 - 1) * 11 + (5 + 0)] = DireCreepTile
doAssert soakL1(view, ty, tx) == 1
doAssert l1(view.y, view.x, ty, tx) == 0

echo "Testing observation parse"
var obs = newString(ObservationSize)
obs[SelfOffset + 0] = char(40)
obs[SelfOffset + 1] = char(90)
obs[SelfOffset + 3] = char(7)
obs[SelfOffset + 12] = char(100)
obs[SelfOffset + 16] = char(0)
obs[SelfOffset + 18] = char(1)  # assassin one-hot
obs[0] = char(TowerTile)
let parsed = parseView(obs)
doAssert parsed.x == 40
doAssert parsed.y == 90
doAssert parsed.health10 == 7
doAssert parsed.eTimer == 100
doAssert parsed.team == 0
doAssert parsed.heroType == 1
doAssert parsed.crop[0] == uint8(TowerTile)

echo "Testing replay still parses r3730-g4 header"
let
  replayPath = currentSourcePath().parentDir / "evidence" / "replays" /
    "r3730-g4.moba"
  replay = parseReplay(readFile(replayPath))
doAssert replay.tickCount == 1827
doAssert replay.playerNames() == @["daveey", "richard"]
doAssert replay.header{"sim_wasm_sha256"}.getStr("") == ExpectedWasmSha
doAssert replay.resultOf(){"winner"}.getInt(-1) == 0
doAssert replay.resultOf(){"final_tick"}.getInt(-1) == 1827

let wasmPath = currentSourcePath().parentDir / "evidence" / "wasm" /
  "moba_sim.wasm"
if fileExists(wasmPath):
  echo "Testing pinned reconstruction of r3730-g4"
  let rec = reconstruct(replayPath, wasmPath)
  doAssert rec.verified
  doAssert rec.scoringEvidence == false
  doAssert rec.simTick == 1827
  doAssert rec.simWinner == "radiant"
  doAssert rec.simEnd == "ancient"
  doAssert rec.heroes[1].role == "assassin"
  doAssert rec.heroes[1].eFires >= 0
  echo "  digest ", rec.simDigest,
    " tower deaths ", rec.towerDeaths.len,
    " assassin E fires ", rec.eFires.len
else:
  echo "Skipping wasm reconstruction test; no ", wasmPath

echo "All trajectory extractor tests passed"
