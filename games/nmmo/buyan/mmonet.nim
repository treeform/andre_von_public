## MMONet: pure Nim port of the upstream PufferLib NMMO3 pretrained policy.
## Ground truth is the vendored demo net in sims/nmmo/vendor/upstream/nmmo3.c
## (init_mmonet + forward) and the puffernet.h primitives it calls
## (_conv2d, _linear, _embedding, mingru, _softmax_multidiscrete). The flat
## nmmo3_weights.bin is consumed in the exact constructor order documented
## in sims/nmmo/sim/brain_shim.c, and every arithmetic step keeps the C
## float32 accumulation order so the logits match the reference bit for bit
## under the same compiler.
##
## Recurrence: four MinGRU layers of 512 floats per brain. A brain is one
## batch-1 net; reset zeroes its state, exactly what the demo does for a
## terminal batch row (nmmo3.c:71-78).
##
## Two weight files are understood, told apart by their size:
##   legacy   nmmo3_weights.bin, 512 x 4, biased conv and projection.
##   puffer5  PufferLib 5.0 nmmo3_1024x4.bin (ocean/nmmo3/nmmo3_net.h over
##            src/puffercpu.c), 1024 x 4, every encoder layer bias-free.
##            Trained with clear_stale_entities=1, so it wants obs=clean.
##
## Sampling: the demo samples the softmax with rand()/RAND_MAX. This port
## draws the uniform from a splitmix64 stream owned by the brain, so the
## action stream is deterministic per (seed, call order) but not equal to
## any libc's rand().

import
  std/[math, os, streams]

type MmonetError* = object of CatchableError

## Observation contract (compute_all_obs, nmmo3.h:926-1020)

const
  ObservationSize* = 1707
  WindowRows = 11
  WindowCols = 15
  TileBytes = 10
  TileFactors = [4, 4, 17, 5, 3, 5, 5, 5, 7, 4]
  MapChannels = 59
  NumScalars = 47
  NumRewards = 10
  ScalarsOffset = WindowRows * WindowCols * TileBytes   # 1650
  RewardsOffset = ScalarsOffset + NumScalars             # 1697

## Network shape (nmmo3.c:30-50)

const
  Conv1Channels = 128
  Conv1Kernel = 5
  Conv1Stride = 3
  Conv1Rows = (WindowRows - Conv1Kernel) div Conv1Stride + 1   # 3
  Conv1Cols = (WindowCols - Conv1Kernel) div Conv1Stride + 1   # 4
  Conv1Outputs = Conv1Channels * Conv1Rows * Conv1Cols         # 1536
  Conv2Channels = 128
  Conv2Kernel = 3
  Conv2Stride = 1
  Conv2Rows = (Conv1Rows - Conv2Kernel) div Conv2Stride + 1    # 1
  Conv2Cols = (Conv1Cols - Conv2Kernel) div Conv2Stride + 1    # 2
  ConvFeatures = Conv2Channels * Conv2Rows * Conv2Cols         # 256
  EmbedRows = 128
  EmbedDim = 32
  EmbedOutputs = NumScalars * EmbedDim                         # 1504
  ProjectionInputs = ConvFeatures + EmbedOutputs + NumScalars +
    NumRewards                                                 # 1817
  NumActions* = 26
  DecoderOutputs = NumActions + 1                              # value head
  LegacyParams* = 4_430_976
  Puffer5Params* = 14_811_520

## Flat weight offsets (float indices). get_weights reads sequentially;
## get_weights_aligned rounds the cursor up to 8 floats AFTER the read.

type
  Layout* = object
    ## Shape of one weight file and where each tensor starts in it.
    hidden*: int
    gruLayers*: int
    biased*: bool                  # legacy conv and projection carry biases
    conv1Weight, conv1Bias: int
    conv2Weight, conv2Bias: int
    embed: int
    projectionWeight, projectionBias: int
    decoder: int
    gru, gruLayerParams: int
    total*: int

proc alignUp(index: int): int =
  (index + 7) and not 7

proc newLayout(hidden, gruLayers: int, biased: bool): Layout =
  result.hidden = hidden
  result.gruLayers = gruLayers
  result.biased = biased
  var cursor = 0
  result.conv1Weight = cursor
  cursor += Conv1Channels * MapChannels * Conv1Kernel * Conv1Kernel
  result.conv1Bias = cursor
  if biased:
    cursor += Conv1Channels
  result.conv2Weight = cursor
  cursor += Conv2Channels * Conv1Channels * Conv2Kernel * Conv2Kernel
  result.conv2Bias = cursor
  if biased:
    cursor += Conv2Channels
  result.embed = cursor
  cursor += EmbedRows * EmbedDim
  result.projectionWeight = cursor
  cursor += hidden * ProjectionInputs
  result.projectionBias = cursor
  if biased:
    cursor += hidden
  else:
    cursor = alignUp(cursor)       # puffercpu.c make_linear is aligned
  result.decoder = cursor
  result.gru = alignUp(cursor + DecoderOutputs * hidden)
  result.gruLayerParams = alignUp(3 * hidden * hidden)
  result.total = result.gru + gruLayers * result.gruLayerParams

const
  LegacyLayout = newLayout(512, 4, true)
  Puffer5Layout = newLayout(1024, 4, false)

static:
  doAssert LegacyLayout.total == LegacyParams
  doAssert Puffer5Layout.total == Puffer5Params

type
  Weights* = ref object
    data*: seq[float32]
    layout*: Layout

  Brain* = object
    weights: Weights
    obMap: seq[float32]            # MapChannels x WindowRows x WindowCols
    conv1Out: seq[float32]         # Conv1Outputs
    conv2Out: seq[float32]         # ConvFeatures
    projectionInput: seq[float32]  # ProjectionInputs
    projectionOut: seq[float32]    # hidden
    gruState: seq[float32]         # gruLayers x hidden
    gruProjection: seq[float32]    # 3 x hidden
    gruInput: seq[float32]         # hidden
    gruOutput: seq[float32]        # hidden
    logits*: seq[float32]          # DecoderOutputs
    rng: uint64

## Weights

proc cleanObservations*(weights: Weights): bool =
  ## True when the net was trained on truthful entity bytes (obs=clean).
  not weights.layout.biased

proc loadWeights*(path: string): Weights =
  ## Reads a little-endian float32 weight file; the size picks the layout.
  let bytes = getFileSize(path)
  var layout: Layout
  if bytes == LegacyParams * sizeof(float32):
    layout = LegacyLayout
  elif bytes == Puffer5Params * sizeof(float32):
    layout = Puffer5Layout
  else:
    raise newException(MmonetError, "weights file has an unknown size " &
      $bytes & ": " & path)
  var stream: FileStream
  try:
    stream = openFileStream(path, fmRead)
  except CatchableError:
    raise newException(MmonetError, "cannot open weights " & path)
  result = Weights(data: newSeq[float32](layout.total), layout: layout)
  let wanted = layout.total * sizeof(float32)
  var got = 0
  try:
    got = stream.readData(result.data[0].addr, wanted)
    if not stream.atEnd():
      raise newException(MmonetError, "weights file is larger than " &
        $wanted & " bytes: " & path)
  finally:
    stream.close()
  if got != wanted:
    raise newException(MmonetError, "weights file is not " & $wanted &
      " bytes: " & path)
  when cpuEndian == bigEndian:
    raise newException(MmonetError, "big-endian hosts are not supported")

## Brain

proc newBrain*(weights: Weights, seed: uint64): Brain =
  ## One batch-1 MMONet with zeroed recurrent state and its own RNG.
  if weights == nil or weights.data.len != weights.layout.total:
    raise newException(MmonetError, "brain needs loaded weights")
  let hidden = weights.layout.hidden
  result.weights = weights
  result.obMap = newSeq[float32](MapChannels * WindowRows * WindowCols)
  result.conv1Out = newSeq[float32](Conv1Outputs)
  result.conv2Out = newSeq[float32](ConvFeatures)
  result.projectionInput = newSeq[float32](ProjectionInputs)
  result.projectionOut = newSeq[float32](hidden)
  result.gruState = newSeq[float32](weights.layout.gruLayers * hidden)
  result.gruProjection = newSeq[float32](3 * hidden)
  result.gruInput = newSeq[float32](hidden)
  result.gruOutput = newSeq[float32](hidden)
  result.logits = newSeq[float32](DecoderOutputs)
  result.rng = seed

proc reset*(brain: var Brain) =
  ## New life: zero every MinGRU layer's state (nmmo3.c:71-78).
  for i in 0 ..< brain.gruState.len:
    brain.gruState[i] = 0'f32

proc nextUint64(brain: var Brain): uint64 =
  ## splitmix64 step.
  brain.rng += 0x9E3779B97F4A7C15'u64
  var z = brain.rng
  z = (z xor (z shr 30)) * 0xBF58476D1CE4E5B9'u64
  z = (z xor (z shr 27)) * 0x94D049BB133111EB'u64
  z xor (z shr 31)

proc uniform(brain: var Brain): float32 =
  ## Uniform float32 in [0, 1), 24 random bits like a float mantissa.
  float32(float64(brain.nextUint64() shr 40) / 16777216.0)

## Layers (puffernet.h). Every accumulation is float32 in the C order.

proc conv2d(input: seq[float32], weights: Weights,
            weightOffset, biasOffset: int, output: var seq[float32],
            inWidth, inHeight, inChannels, outChannels, kernel,
            stride: int) =
  ## _conv2d: output[oc][h][w] = bias[oc] + sum over ic, kh, kw. The
  ## bias-free layout starts the sum at zero like puffercpu.c.
  let biased = weights.layout.biased
  let hOut = (inHeight - kernel) div stride + 1
  let wOut = (inWidth - kernel) div stride + 1
  for oc in 0 ..< outChannels:
    for h in 0 ..< hOut:
      for w in 0 ..< wOut:
        var acc = if biased: weights.data[biasOffset + oc] else: 0'f32
        for ic in 0 ..< inChannels:
          for kh in 0 ..< kernel:
            let inRow = ic * inHeight * inWidth + (h * stride + kh) * inWidth +
              w * stride
            let weightRow = weightOffset +
              oc * inChannels * kernel * kernel + ic * kernel * kernel +
              kh * kernel
            for kw in 0 ..< kernel:
              acc += input[inRow + kw] * weights.data[weightRow + kw]
        output[oc * hOut * wOut + h * wOut + w] = acc

proc relu(values: var seq[float32]) =
  for i in 0 ..< values.len:
    if values[i] < 0'f32:
      values[i] = 0'f32

proc affine(input: seq[float32], weights: Weights,
            weightOffset, biasOffset: int, output: var seq[float32],
            inputDim, outputDim: int) =
  ## _linear with bias: out[o] = sum_i in[i] * w[o][i] + b[o]. The
  ## bias-free layout stops at the sum.
  let biased = weights.layout.biased
  for o in 0 ..< outputDim:
    var acc = 0'f32
    let row = weightOffset + o * inputDim
    for i in 0 ..< inputDim:
      acc += input[i] * weights.data[row + i]
    output[o] = if biased: acc + weights.data[biasOffset + o] else: acc

proc linear(input: seq[float32], weights: Weights, weightOffset: int,
            output: var seq[float32], inputDim, outputDim: int) =
  ## linear without bias: out[o] = sum_i in[i] * w[o][i].
  for o in 0 ..< outputDim:
    var acc = 0'f32
    let row = weightOffset + o * inputDim
    for i in 0 ..< inputDim:
      acc += input[i] * weights.data[row + i]
    output[o] = acc

proc sigmoid(x: float32): float32 =
  1'f32 / (1'f32 + exp(-x))

proc mingru(brain: var Brain) =
  ## Stacked MinGRU layers with the fused gate + highway connection.
  ## Input is brain.gruInput; the last layer's output lands in gruOutput.
  let layout = brain.weights.layout
  let width = layout.hidden
  for layer in 0 ..< layout.gruLayers:
    let offset = layout.gru + layer * layout.gruLayerParams
    linear(brain.gruInput, brain.weights, offset, brain.gruProjection,
           width, 3 * width)
    let stateBase = layer * width
    for h in 0 ..< width:
      let hidden = brain.gruProjection[h]
      let gate = brain.gruProjection[width + h]
      let highway = brain.gruProjection[2 * width + h]
      let state = brain.gruState[stateBase + h]
      let gateS = sigmoid(gate)
      var candidate: float32
      if hidden >= 0'f32:
        candidate = hidden + 0.5'f32
      else:
        candidate = sigmoid(hidden)
      let updated = state + gateS * (candidate - state)
      let highwayS = sigmoid(highway)
      brain.gruOutput[h] = highwayS * updated +
        (1'f32 - highwayS) * brain.gruInput[h]
      brain.gruState[stateBase + h] = updated
    if layer + 1 < layout.gruLayers:
      for h in 0 ..< width:
        brain.gruInput[h] = brain.gruOutput[h]

## Forward

proc forward*(brain: var Brain, observation: openArray[uint8]) =
  ## One inference step: 1707 obs bytes -> brain.logits (26 actions +
  ## value). Advances the recurrent state. Out-of-range bytes are clamped
  ## to their table sizes exactly like sim/brain_shim.c.
  if observation.len != ObservationSize:
    raise newException(MmonetError, "observation must be " &
      $ObservationSize & " bytes, got " & $observation.len)

  # 59-channel one-hot of the 11x15x10 tile window.
  for i in 0 ..< brain.obMap.len:
    brain.obMap[i] = 0'f32
  for row in 0 ..< WindowRows:
    for col in 0 ..< WindowCols:
      var channel = 0
      for f in 0 ..< TileBytes:
        var value = int(observation[row * WindowCols * TileBytes +
          col * TileBytes + f])
        if value >= TileFactors[f]:
          value = TileFactors[f] - 1
        brain.obMap[(channel + value) * WindowRows * WindowCols +
          row * WindowCols + col] = 1'f32
        channel += TileFactors[f]
  let layout = brain.weights.layout
  conv2d(brain.obMap, brain.weights, layout.conv1Weight, layout.conv1Bias,
         brain.conv1Out, WindowCols, WindowRows, MapChannels,
         Conv1Channels, Conv1Kernel, Conv1Stride)
  relu(brain.conv1Out)
  conv2d(brain.conv1Out, brain.weights, layout.conv2Weight, layout.conv2Bias,
         brain.conv2Out, Conv1Cols, Conv1Rows, Conv1Channels,
         Conv2Channels, Conv2Kernel, Conv2Stride)

  # Concatenate [conv 256 | scalar embeddings 47x32 | scalars 47 |
  # rewards 10] into the projection input.
  for i in 0 ..< ConvFeatures:
    brain.projectionInput[i] = brain.conv2Out[i]
  var cursor = ConvFeatures
  for i in 0 ..< NumScalars:
    var id = int(observation[ScalarsOffset + i])
    if id >= EmbedRows:
      id = EmbedRows - 1
    let row = layout.embed + id * EmbedDim
    for k in 0 ..< EmbedDim:
      brain.projectionInput[cursor + i * EmbedDim + k] =
        brain.weights.data[row + k]
  cursor += EmbedOutputs
  for i in 0 ..< NumScalars:
    brain.projectionInput[cursor + i] =
      float32(observation[ScalarsOffset + i])
  cursor += NumScalars
  for i in 0 ..< NumRewards:
    brain.projectionInput[cursor + i] =
      float32(observation[RewardsOffset + i])

  affine(brain.projectionInput, brain.weights, layout.projectionWeight,
         layout.projectionBias, brain.projectionOut, ProjectionInputs,
         layout.hidden)
  relu(brain.projectionOut)
  for h in 0 ..< layout.hidden:
    brain.gruInput[h] = brain.projectionOut[h]
  brain.mingru()
  linear(brain.gruOutput, brain.weights, layout.decoder, brain.logits,
         layout.hidden, DecoderOutputs)

proc sample*(brain: var Brain, temperature = 1'f32): int =
  ## _softmax_multidiscrete over the 26 action logits: cumulative
  ## exp/sum against one uniform draw, falling back to the last action.
  ## The reference exponentiates raw logits; this subtracts the max first,
  ## which is the same distribution without float32 overflow (the
  ## reference degenerates to action 0 once any logit passes ~88).
  ## temperature scales the logits (1 = the reference distribution,
  ## lower = sharper); a non-positive temperature means argmax.
  var best = brain.logits[0]
  var bestIndex = 0
  for i in 1 ..< NumActions:
    if brain.logits[i] > best:
      best = brain.logits[i]
      bestIndex = i
  if temperature <= 0'f32:
    return bestIndex
  var expSum = 0'f32
  for i in 0 ..< NumActions:
    expSum += exp((brain.logits[i] - best) / temperature)
  let draw = brain.uniform()
  var cumulative = 0'f32
  for i in 0 ..< NumActions:
    cumulative += exp((brain.logits[i] - best) / temperature) / expSum
    if draw < cumulative:
      return i
  NumActions - 1

proc argmax*(brain: Brain): int =
  ## Greedy action from the current logits (for diagnostics and tests).
  result = 0
  for i in 1 ..< NumActions:
    if brain.logits[i] > brain.logits[result]:
      result = i

proc act*(brain: var Brain, observation: openArray[uint8],
          temperature = 1'f32): int =
  ## forward + sample: the demo's per-tick policy call.
  brain.forward(observation)
  brain.sample(temperature)
