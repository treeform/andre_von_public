## Faithful Nim port of pretrained NMMO MMONet (puffernet / brain_shim.c).
## Shared immutable float32 weights, per-agent MinGRU state, reset, forward
## logits, and a categorical sampler. Scalar float32 math.

import std/[math, os, random, streams]

const
  windowRows* = 11
  windowCols* = 15
  tileBytes* = 10
  numScalars* = 47
  scalarsOffset* = windowRows * windowCols * tileBytes ## 1650
  rewardBytes* = 10
  observationSize* = scalarsOffset + numScalars + rewardBytes ## 1707
  mapChannels* = 59
  embedVocab* = 128
  embedDim* = 32
  conv1Out* = 128
  conv2Out* = 128
  conv1Kh* = 5
  conv1Stride* = 3
  conv2Kh* = 3
  conv2Stride* = 1
  conv1H* = 3
  conv1W* = 4
  conv2H* = 1
  conv2W* = 2
  convFlat* = conv2Out * conv2H * conv2W ## 256
  embedFlat* = numScalars * embedDim ## 1504
  projIn* = convFlat + embedFlat + numScalars + rewardBytes ## 1817
  hiddenSize* = 512
  gruLayers* = 4
  decoderOut* = 27
  numActions* = 26
  expectedParams* = 4_430_976
  expectedBytes* = expectedParams * sizeof(float32)
  tileFactors* = [4, 4, 17, 5, 3, 5, 5, 5, 7, 4]

  conv1WOff* = 0
  conv1WCount* = conv1Out * mapChannels * conv1Kh * conv1Kh ## 188800
  conv1BOff* = conv1WOff + conv1WCount ## 188800
  conv1BCount* = conv1Out
  conv2WOff* = conv1BOff + conv1BCount ## 188928
  conv2WCount* = conv2Out * conv1Out * conv2Kh * conv2Kh ## 147456
  conv2BOff* = conv2WOff + conv2WCount ## 336384
  conv2BCount* = conv2Out
  embedOff* = conv2BOff + conv2BCount ## 336512
  embedCount* = embedVocab * embedDim ## 4096
  affineWOff* = embedOff + embedCount ## 340608
  affineWCount* = projIn * hiddenSize ## 930304
  affineBOff* = affineWOff + affineWCount ## 1270912
  affineBCount* = hiddenSize
  decoderOff* = affineBOff + affineBCount ## 1271424
  decoderCount* = hiddenSize * decoderOut ## 13824
  mingruOff* = decoderOff + decoderCount ## 1285248
  mingruLayerCount* = hiddenSize * (3 * hiddenSize) ## 786432
  mingruTotal* = gruLayers * mingruLayerCount

doAssert conv1BOff + conv1BCount == conv2WOff
doAssert conv2BOff + conv2BCount == embedOff
doAssert embedOff + embedCount == affineWOff
doAssert affineBOff + affineBCount == decoderOff
doAssert decoderOff + decoderCount == mingruOff
doAssert mingruOff + mingruTotal == expectedParams

type
  Weights* = object
    data*: seq[float32]

  AgentState* = object
    gru*: array[gruLayers, array[hiddenSize, float32]]

  Network* = object
    weights*: Weights
    agents*: seq[AgentState]
    rng*: Rand
    resetCount*: int
    lastInferenceNs*: int64

proc isFinite32(x: float32): bool =
  let c = classify(float(x))
  c != fcNan and c != fcInf and c != fcNegInf

proc sigmoid32*(x: float32): float32 =
  1.0'f32 / (1.0'f32 + exp(-x).float32)

proc relu32*(x: float32): float32 =
  if x > 0'f32: x else: 0'f32

proc linear*(input: openArray[float32]; weights: openArray[float32];
             outputDim, inputDim: int;
             output: var openArray[float32];
             bias: ptr UncheckedArray[float32] = nil) =
  ## Output-major dense: y[o] = (bias[o] if present) + sum_i x[i]*W[o,i].
  for o in 0 ..< outputDim:
    var s = if bias != nil: bias[o] else: 0'f32
    let row = o * inputDim
    for i in 0 ..< inputDim:
      s += input[i] * weights[row + i]
    output[o] = s

proc conv2d*(input: openArray[float32]; weights, bias: openArray[float32];
             inH, inW, inC, outC, k, stride: int;
             output: var openArray[float32]) =
  ## OIHW conv, NCHW tensors, batch=1. Matches puffernet _conv2d.
  let outH = (inH - k) div stride + 1
  let outW = (inW - k) div stride + 1
  for oc in 0 ..< outC:
    for h in 0 ..< outH:
      for w in 0 ..< outW:
        var s = bias[oc]
        for ic in 0 ..< inC:
          for kh in 0 ..< k:
            for kw in 0 ..< k:
              let inAdr = ic * inH * inW + (h * stride + kh) * inW +
                          (w * stride + kw)
              let wAdr = oc * inC * k * k + ic * k * k + kh * k + kw
              s += input[inAdr] * weights[wAdr]
        output[oc * outH * outW + h * outW + w] = s

proc minGruStep*(hidden, gate, highway, oldState, x: float32):
    tuple[newState, output: float32] =
  let gateS = sigmoid32(gate)
  let hTilde = if hidden >= 0'f32: hidden + 0.5'f32 else: sigmoid32(hidden)
  let newState = oldState + gateS * (hTilde - oldState)
  let hwS = sigmoid32(highway)
  (newState, hwS * newState + (1.0'f32 - hwS) * x)

proc resetAgent*(agent: var AgentState) =
  for l in 0 ..< gruLayers:
    for h in 0 ..< hiddenSize:
      agent.gru[l][h] = 0'f32

proc validateOffsets*(): int =
  ## Returns the exclusive end offset; must equal expectedParams.
  mingruOff + mingruTotal

proc loadWeights*(path: string): Weights =
  if not fileExists(path):
    raise newException(IOError, "weights.bin not found: " & path)
  let n = getFileSize(path)
  if n != expectedBytes:
    raise newException(IOError, "weights.bin size " & $n &
                       " != " & $expectedBytes)
  result.data = newSeq[float32](expectedParams)
  var fs = newFileStream(path, fmRead)
  if fs.isNil:
    raise newException(IOError, "cannot open " & path)
  defer: fs.close()
  if fs.readData(addr result.data[0], expectedBytes) != expectedBytes:
    raise newException(IOError, "short read of weights.bin")
  for i, w in result.data:
    if not isFinite32(w):
      raise newException(IOError, "non-finite weight at " & $i)

proc defaultWeightsPath*(): string =
  getAppDir() / "weights.bin"

proc sourceWeightsPath*(): string =
  currentSourcePath().parentDir / "weights.bin"

proc oneHotMap(obs: openArray[uint8]; map: var seq[float32]) =
  for i in 0 ..< map.len:
    map[i] = 0'f32
  const factors = tileFactors
  for r in 0 ..< windowRows:
    for c in 0 ..< windowCols:
      var fOff = 0
      for f in 0 ..< 10:
        var ob = int(obs[r * windowCols * tileBytes + c * tileBytes + f])
        if ob >= factors[f]:
          ob = factors[f] - 1
        let ch = fOff + ob
        map[ch * windowRows * windowCols + r * windowCols + c] = 1'f32
        fOff += factors[f]

proc forwardLogits*(w: Weights; agent: var AgentState;
                    obs: openArray[uint8]): array[decoderOut, float32] =
  ## One-agent MMONet forward. Updates `agent.gru` in place.
  var map = newSeq[float32](mapChannels * windowRows * windowCols)
  oneHotMap(obs, map)

  var conv1 = newSeq[float32](conv1Out * conv1H * conv1W)
  conv2d(map,
         w.data.toOpenArray(conv1WOff, conv1WOff + conv1WCount - 1),
         w.data.toOpenArray(conv1BOff, conv1BOff + conv1BCount - 1),
         windowRows, windowCols, mapChannels, conv1Out, conv1Kh, conv1Stride,
         conv1)
  for i in 0 ..< conv1.len:
    conv1[i] = relu32(conv1[i])

  var conv2 = newSeq[float32](convFlat)
  conv2d(conv1,
         w.data.toOpenArray(conv2WOff, conv2WOff + conv2WCount - 1),
         w.data.toOpenArray(conv2BOff, conv2BOff + conv2BCount - 1),
         conv1H, conv1W, conv1Out, conv2Out, conv2Kh, conv2Stride,
         conv2)
  ## No ReLU after conv2.

  var proj = newSeq[float32](projIn)
  for i in 0 ..< convFlat:
    proj[i] = conv2[i]
  var eOff = convFlat
  for s in 0 ..< numScalars:
    var id = int(obs[scalarsOffset + s])
    if id >= embedVocab:
      id = embedVocab - 1
    let row = embedOff + id * embedDim
    for d in 0 ..< embedDim:
      proj[eOff + s * embedDim + d] = w.data[row + d]
  var cOff = convFlat + embedFlat
  for s in 0 ..< numScalars:
    proj[cOff + s] = float32(obs[scalarsOffset + s])
  var rOff = cOff + numScalars
  for i in 0 ..< rewardBytes:
    proj[rOff + i] = float32(obs[scalarsOffset + numScalars + i])

  var h = newSeq[float32](hiddenSize)
  linear(proj,
         w.data.toOpenArray(affineWOff, affineWOff + affineWCount - 1),
         hiddenSize, projIn, h,
         cast[ptr UncheckedArray[float32]](addr w.data[affineBOff]))
  for i in 0 ..< hiddenSize:
    h[i] = relu32(h[i])

  var x = h
  var combined: array[3 * hiddenSize, float32]
  var nxt: array[hiddenSize, float32]
  for l in 0 ..< gruLayers:
    let po = mingruOff + l * mingruLayerCount
    linear(x,
           w.data.toOpenArray(po, po + mingruLayerCount - 1),
           3 * hiddenSize, hiddenSize, combined)
    for hi in 0 ..< hiddenSize:
      let step = minGruStep(combined[hi], combined[hiddenSize + hi],
                            combined[2 * hiddenSize + hi],
                            agent.gru[l][hi], x[hi])
      agent.gru[l][hi] = step.newState
      nxt[hi] = step.output
    x = @nxt

  linear(x,
         w.data.toOpenArray(decoderOff, decoderOff + decoderCount - 1),
         decoderOut, hiddenSize, result)

proc sampleCategorical*(rng: var Rand; logits: openArray[float32];
                        n: int): int =
  ## Softmax sample over logits[0 ..< n]. Not argmax. Matches
  ## puffernet _softmax_multidiscrete (no max-subtraction).
  var sum = 0'f32
  for i in 0 ..< n:
    sum += exp(logits[i]).float32
  let prob = rng.rand(1.0).float32
  var acc = 0'f32
  result = 0
  for i in 0 ..< n:
    acc += exp(logits[i]).float32 / sum
    if prob < acc:
      return i

proc sampleAction*(rng: var Rand; logits: openArray[float32]): int =
  sampleCategorical(rng, logits, numActions)

proc initNetwork*(path: string; seed: int; numAgents = 0): Network =
  result.weights = loadWeights(path)
  result.rng = initRand(seed)
  result.agents = newSeq[AgentState](numAgents)
  for i in 0 ..< numAgents:
    result.agents[i].resetAgent()

proc ensureAgents*(net: var Network; n: int) =
  while net.agents.len < n:
    var a: AgentState
    a.resetAgent()
    net.agents.add(a)

proc resetHero*(net: var Network; i: int) =
  if i >= 0 and i < net.agents.len:
    net.agents[i].resetAgent()
    inc net.resetCount
