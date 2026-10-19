## Isolation inference checks for MMONet. Compile with -d:buyanTest.
## Not a game score.

import std/[json, math, monotimes, os, random, times]
include candidate

proc synthObs(): string =
  result = newString(observationSize)
  for i in 0 ..< observationSize:
    result[i] = char(0)
  # valid tile factors: terrain grass, rest zeros
  for r in 0 ..< windowRows:
    for c in 0 ..< windowCols:
      let base = (r * windowCols + c) * tileBytes
      result[base + 0] = char(0)
      result[base + 1] = char(0)
  result[scalarsOffset + 5] = char(100)
  result[scalarsOffset + 1] = char(1)

proc allFinite(logits: openArray[float32]): bool =
  for x in logits:
    let c = classify(float(x))
    if c == fcNan or c == fcInf or c == fcNegInf:
      return false
  true

echo "parameter offsets"
doAssert mmo.conv1WOff == 0
doAssert mmo.conv1WCount == 128 * 59 * 5 * 5
doAssert mmo.conv1BOff == 188800
doAssert mmo.conv2WOff == 188928
doAssert mmo.conv2WCount == 128 * 128 * 3 * 3
doAssert mmo.embedOff == 336512
doAssert mmo.embedCount == 128 * 32
doAssert mmo.affineWOff == 340608
doAssert mmo.affineWCount == 1817 * 512
doAssert mmo.affineBOff == 1_270_912
doAssert mmo.decoderOff == 1_271_424
doAssert mmo.decoderCount == 512 * 27
doAssert mmo.mingruOff == 1_285_248
doAssert mmo.mingruLayerCount == 512 * 1536
doAssert mmo.validateOffsets() == mmo.expectedParams
doAssert mmo.expectedBytes == 17_723_904
doAssert mmo.mingruOff + 4 * mmo.mingruLayerCount == mmo.expectedParams

echo "dense fixture"
block:
  var inp = [1'f32, 2'f32, 3'f32]
  var w = [
    1'f32, 0'f32, 0'f32,
    0'f32, 1'f32, 0'f32,
    0'f32, 0'f32, 1'f32,
    1'f32, 1'f32, 1'f32
  ]
  var b = [0.5'f32, -1'f32, 2'f32, 0'f32]
  var y: array[4, float32]
  mmo.linear(inp, w, 4, 3, y, cast[ptr UncheckedArray[float32]](addr b[0]))
  doAssert y[0] == 1.5'f32
  doAssert y[1] == 1'f32
  doAssert y[2] == 5'f32
  doAssert y[3] == 6'f32
  var y2: array[4, float32]
  mmo.linear(inp, w, 4, 3, y2)
  doAssert y2[0] == 1'f32
  doAssert y2[3] == 6'f32

echo "conv fixture"
block:
  # 1x2x2 input, 1 out channel, k=2, stride=1 -> 1x1
  var inp = [1'f32, 2'f32, 3'f32, 4'f32]
  var wt = [1'f32, 0'f32, 0'f32, 1'f32]
  var bs = [0.25'f32]
  var y: array[1, float32]
  mmo.conv2d(inp, wt, bs, 2, 2, 1, 1, 2, 1, y)
  doAssert y[0] == 1'f32 + 4'f32 + 0.25'f32

echo "minGRU fixture"
block:
  let s = mmo.minGruStep(2'f32, 0'f32, 0'f32, 1'f32, 4'f32)
  # gate=sigmoid(0)=0.5; h_tilde=2.5; new=1+0.5*(2.5-1)=1.75
  # hw=0.5; out=0.5*1.75+0.5*4=2.875
  doAssert abs(s.newState - 1.75'f32) < 1e-6'f32
  doAssert abs(s.output - 2.875'f32) < 1e-6'f32
  let n = mmo.minGruStep(-100'f32, 100'f32, -100'f32, 0'f32, 3'f32)
  # hidden<0 -> sigmoid(~0); gate~1; new~0; hw~0; out~x=3
  doAssert abs(n.output - 3'f32) < 1e-5'f32

echo "sampler reproducibility and bounds (not argmax)"
block:
  var logits = [5'f32, 5'f32, 5'f32, 0'f32, 0'f32, 0'f32, 0'f32, 0'f32,
                0'f32, 0'f32, 0'f32, 0'f32, 0'f32, 0'f32, 0'f32, 0'f32,
                0'f32, 0'f32, 0'f32, 0'f32, 0'f32, 0'f32, 0'f32, 0'f32,
                0'f32, 0'f32]
  var a = initRand(1)
  var b = initRand(1)
  let x = mmo.sampleCategorical(a, logits, 26)
  let y = mmo.sampleCategorical(b, logits, 26)
  doAssert x == y
  doAssert x >= 0 and x < 26
  var c = initRand(2)
  var seen: set[uint8]
  for i in 0 ..< 64:
    let z = mmo.sampleCategorical(c, logits, 26)
    doAssert z >= 0 and z < 26
    seen.incl(uint8(z))
  doAssert seen.len >= 2
  # argmax of equal 5s would be index 0; a non-degenerate stream must
  # be allowed to pick another tied class
  var d = initRand(7)
  var hitNonZero = false
  for i in 0 ..< 32:
    if mmo.sampleCategorical(d, logits, 3) != 0:
      hitNonZero = true
      break
  doAssert hitNonZero

echo "load weights"
let wpath = mmo.sourceWeightsPath()
doAssert fileExists(wpath)
doAssert getFileSize(wpath) == mmo.expectedBytes
let w = mmo.loadWeights(wpath)
doAssert w.data.len == mmo.expectedParams
doAssert mmo.validateOffsets() == w.data.len

echo "finite logits on synthetic obs"
block:
  var agent: mmo.AgentState
  mmo.resetAgent(agent)
  var bytes = newSeq[uint8](observationSize)
  let o = synthObs()
  for i in 0 ..< observationSize:
    bytes[i] = o[i].uint8
  let logits = mmo.forwardLogits(w, agent, bytes)
  doAssert logits.len == 27
  doAssert allFinite(logits)

echo "reset reproduces logits and isolates other hero"
block:
  var a0, a1, fresh: mmo.AgentState
  mmo.resetAgent(a0)
  mmo.resetAgent(a1)
  mmo.resetAgent(fresh)
  var bytes = newSeq[uint8](observationSize)
  let o = synthObs()
  for i in 0 ..< observationSize:
    bytes[i] = o[i].uint8
  discard mmo.forwardLogits(w, a0, bytes)
  discard mmo.forwardLogits(w, a1, bytes)
  discard mmo.forwardLogits(w, a1, bytes)
  var snap1 = a1
  mmo.resetAgent(a0)
  let l0 = mmo.forwardLogits(w, a0, bytes)
  let lf = mmo.forwardLogits(w, fresh, bytes)
  doAssert l0 == lf
  for h in 0 ..< mmo.hiddenSize:
    doAssert snap1.gru[0][h] == a1.gru[0][h]
    doAssert snap1.gru[3][h] == a1.gru[3][h]
  let l1a = mmo.forwardLogits(w, a1, bytes)
  # a1 was not reset; continuing from snap, so a1 after another forward
  # must differ from a freshly reset pair
  doAssert l1a != lf

echo "wire selection path"
block:
  neuralEvents = @[]
  var net = mmo.initNetwork(wpath, 11, 0)
  var shadows: seq[Mind]
  let o = synthObs()
  let acts = processTick(net, shadows, 11, 0, @[o, o], @[true, false])
  doAssert acts.len == 2
  doAssert acts[0] >= 0 and acts[0] < 26
  doAssert acts[1] >= 0 and acts[1] < 26
  doAssert net.resetCount == 1
  doAssert net.lastInferenceNs >= 0
  doAssert shadows.len == 2
  for ev in neuralEvents:
    doAssert ev["experiment"].getStr() == "neural"
    doAssert ev["event"].getStr() == "strategy_action"
    doAssert ev.hasKey("tick")
    doAssert ev.hasKey("agent")
    doAssert ev.hasKey("action")
    doAssert ev.hasKey("baselineAction")
    doAssert ev.hasKey("generation")
    doAssert ev["action"].getInt() != ev["baselineAction"].getInt()
  let again = processTick(net, shadows, 11, 1, @[o], @[false])
  doAssert again.len == 1
  doAssert again[0] >= 0 and again[0] < 26

echo "malformed obs is noop on wire path"
block:
  var net = mmo.initNetwork(wpath, 3, 1)
  doAssert selectNeuralAction(net, 0, "short") == noopAction

echo "benchmark forward"
block:
  var agent: mmo.AgentState
  mmo.resetAgent(agent)
  var bytes = newSeq[uint8](observationSize)
  let o = synthObs()
  for i in 0 ..< observationSize:
    bytes[i] = o[i].uint8
  discard mmo.forwardLogits(w, agent, bytes)
  const n = 8
  let t0 = getMonoTime()
  for i in 0 ..< n:
    discard mmo.forwardLogits(w, agent, bytes)
  let ns = (getMonoTime() - t0).inNanoseconds
  echo "forward_ns_total=", ns, " n=", n, " mean_ns=", ns div n
  echo "machine=", hostOS, "/", hostCPU
  echo "nim=", NimVersion

echo "ok neural inference checks"
