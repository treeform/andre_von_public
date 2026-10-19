## Parity test: the pure Nim MMONet against the vendored C reference
## (brain_c.c = nmmo3.c init_mmonet/forward over puffernet.h, logits out).
## Feeds identical synthetic observation sequences with mid-sequence
## resets to both and reports the largest logit difference. This is an
## isolation test of the port, never a game or a score.
##
## Run from this directory:
##   nim r -d:release --passC:-ffp-contract=off parity.nim
## The PufferLib 5.0 1024 x 4 net against its own C reference
## (brain5_c.c = src/puffercpu.c + ocean/nmmo3/nmmo3_net.h):
##   nim r -d:release -d:puffer5 --passC:-ffp-contract=off parity.nim

import
  std/[os, strutils],
  ../mmonet

const
  puffer5 {.booldefine.} = false
  References = "/Users/me/p/andre_von_auto/references"
when puffer5:
  const
    UpstreamInclude = References & "/pufferlib5"
    DefaultWeights = References & "/pufferlib5_models/nmmo3_1024x4.bin"
else:
  const
    UpstreamInclude = "/Users/me/p/andre_von_auto/sims/nmmo/vendor/upstream"
    DefaultWeights = UpstreamInclude & "/resources/nmmo3/nmmo3_weights.bin"
const
  Ticks = 400
  ResetTicks = [0, 57, 58, 190, 333]
  TileFactors = [4, 4, 17, 5, 3, 5, 5, 5, 7, 4]

{.passc: "-I" & UpstreamInclude.}
when puffer5:
  {.compile: "brain5_c.c".}

  proc brain5Create(path: cstring, numAgents, hidden, layers: cint): pointer
    {.importc: "brain5_create".}
  proc brainForward(handle: pointer, obs: ptr uint8, terminals: ptr cfloat,
                    output: ptr cfloat) {.importc: "brain5_forward".}

  proc brainCreate(path: cstring, numAgents: cint): pointer =
    brain5Create(path, numAgents, 1024, 4)
else:
  {.compile: "brain_c.c".}

  proc brainCreate(path: cstring, numAgents: cint): pointer
    {.importc: "brain_create".}
  proc brainForward(handle: pointer, obs: ptr uint8, terminals: ptr cfloat,
                    output: ptr cfloat) {.importc: "brain_forward".}

var rngState = 0x1234'u64

proc nextRandom(): uint64 =
  rngState += 0x9E3779B97F4A7C15'u64
  var z = rngState
  z = (z xor (z shr 30)) * 0xBF58476D1CE4E5B9'u64
  z = (z xor (z shr 27)) * 0x94D049BB133111EB'u64
  z xor (z shr 31)

proc randomObservation(): seq[uint8] =
  ## Contract-valid random obs: tile bytes below their factors, scalars
  ## and rewards anywhere in 0..127 (embedding rows are 0..127).
  result = newSeq[uint8](ObservationSize)
  for cell in 0 ..< 11 * 15:
    for f in 0 ..< 10:
      result[cell * 10 + f] = uint8(nextRandom() mod uint64(TileFactors[f]))
  for i in 1650 ..< ObservationSize:
    result[i] = uint8(nextRandom() mod 128)

proc main() =
  let weightsPath = if paramCount() >= 1: paramStr(1) else: DefaultWeights
  let weights = loadWeights(weightsPath)
  var nim = newBrain(weights, 7)
  let oracle = brainCreate(cstring(weightsPath), 1)
  doAssert oracle != nil, "oracle could not load weights"
  var terminals = [0'f32]
  var output = newSeq[cfloat](27)
  var worst = 0'f64
  var worstTick = -1
  var argmaxMismatches = 0
  for tick in 0 ..< Ticks:
    var observation = randomObservation()
    if tick in ResetTicks:
      terminals[0] = 1'f32
      nim.reset()
    brainForward(oracle, observation[0].addr, terminals[0].addr,
                 output[0].addr)
    nim.forward(observation)
    var oracleBest = 0
    var tickWorst = 0'f64
    for i in 0 ..< 27:
      let diff = abs(float64(output[i]) - float64(nim.logits[i]))
      if diff > tickWorst:
        tickWorst = diff
      if diff > worst:
        worst = diff
        worstTick = tick
      if i < 26 and output[i] > output[oracleBest]:
        oracleBest = i
    if oracleBest != nim.argmax():
      inc argmaxMismatches
    if tick < 4 or tick in ResetTicks or tick mod 50 == 49:
      var spread = 0'f64
      for i in 0 ..< 26:
        spread = max(spread, float64(abs(output[i] - output[oracleBest])))
      echo "tick ", tick, " max diff ", formatFloat(tickWorst, ffScientific, 2),
        " best ", oracleBest, " logit ", formatFloat(float64(output[oracleBest]), ffDecimal, 2),
        " spread ", formatFloat(spread, ffDecimal, 2)
  echo "ticks ", Ticks, " resets ", ResetTicks.len
  echo "max |logit diff| ", formatFloat(worst, ffScientific, 3),
    " at tick ", worstTick
  echo "argmax mismatches ", argmaxMismatches
  var actions = newSeq[int](26)
  for i in 0 ..< 2000:
    inc actions[nim.sample()]
  echo "sampler histogram over last logits ", actions
  doAssert worst < 1e-4, "logits diverge from the C reference"
  doAssert argmaxMismatches == 0, "argmax diverges from the C reference"
  echo "parity: OK"

main()
