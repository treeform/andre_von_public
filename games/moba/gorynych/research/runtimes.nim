## Wasmtime host for the pinned MOBA sim, matching sim.py init/replay.
## WASI reactor: growth stub, _initialize, moba_init(seed bits, 10).
## Reconstruction only: recorded actions in, exported state out.

import
  std/strutils,
  wasmtimes

const
  NumAgents* = 10
  ObsSize* = 510
  NumAtns* = 6
  ActHigh* = [7, 7, 3, 2, 2, 2]

type
  ReconstructionError* = object of CatchableError
  ExportFn = object
    raw: WasmtimeFunc
    have: bool
  MobaRuntime* = ref object
    engine: ptr WasmEngine
    store: ptr WasmtimeStore
    context: ptr WasmtimeContext
    module: ptr WasmtimeModule
    linker: ptr WasmtimeLinker
    instance: WasmtimeInstance
    memory: WasmtimeMemory
    haveMemory: bool
    fnInit: ExportFn
    fnStep: ExportFn
    fnObs: ExportFn
    fnAct: ExportFn
    fnDone: ExportFn
    fnWinner: ExportFn
    fnTick: ExportFn
    fnFault: ExportFn
    fnStat: ExportFn
    fnDigest: ExportFn
    fnAncient: ExportFn
    obsPtr: int32
    actPtr: int32
    closed: bool

proc raiseRecon*(message: string) {.raises: [ReconstructionError].} =
  ## Raises ReconstructionError with message.
  raise newException(ReconstructionError, message)

proc byteVecString(bytes: WasmByteVec): string =
  ## Copies a Wasmtime byte vector into a Nim string.
  result = newString(bytes.size.int)
  if bytes.size > 0:
    copyMem(addr result[0], bytes.data, bytes.size)

proc consumeError(error: ptr WasmtimeError): string =
  ## Consumes one owned Wasmtime error.
  if error == nil:
    return ""
  var message: WasmByteVec
  wasmtimeErrorMessage(error, addr message)
  result = byteVecString(message).strip(chars = {'\0', '\n'})
  wasmByteVecDelete(addr message)
  wasmtimeErrorDelete(error)

proc consumeTrap(trap: ptr WasmTrap): string =
  ## Consumes one owned Wasmtime trap.
  if trap == nil:
    return ""
  var message: WasmByteVec
  wasmTrapMessage(trap, addr message)
  result = byteVecString(message).strip(chars = {'\0', '\n'})
  wasmByteVecDelete(addr message)
  wasmTrapDelete(trap)

proc requireNoError(error: ptr WasmtimeError, operation: string) =
  ## Raises if error is non-nil.
  if error != nil:
    raiseRecon(operation & ": " & consumeError(error))

proc requireNoTrap(trap: ptr WasmTrap, operation: string) =
  ## Raises if trap is non-nil.
  if trap != nil:
    raiseRecon(operation & " trapped: " & consumeTrap(trap))

proc notifyGrowth(env: pointer; caller: ptr WasmtimeCaller;
    args: ptr WasmtimeConstVal; nargs: csize_t; results: ptr WasmtimeVal;
    nresults: csize_t): ptr WasmTrap {.cdecl.} =
  ## No-op host stub for emscripten_notify_memory_growth.
  discard env
  discard caller
  discard args
  discard nargs
  discard results
  discard nresults
  nil

proc bitsToFloat32(bits: int32): float32 =
  ## Reinterprets i32 bits as f32 (ancient_health return).
  var n = bits
  copyMem(addr result, addr n, 4)

proc seedBits*(seed: int64): int32 =
  ## Unsigned-32 seed as the signed i32 wasm ABI bit pattern.
  cast[int32](uint32(seed and 0xFFFFFFFF'i64))

proc close*(runtime: MobaRuntime) =
  ## Drops store, module, linker, engine exactly once.
  if runtime == nil or runtime.closed:
    return
  runtime.closed = true
  if runtime.store != nil:
    wasmtimeStoreDelete(runtime.store)
    runtime.store = nil
    runtime.context = nil
  if runtime.linker != nil:
    wasmtimeLinkerDelete(runtime.linker)
    runtime.linker = nil
  if runtime.module != nil:
    wasmtimeModuleDelete(runtime.module)
    runtime.module = nil
  if runtime.engine != nil:
    wasmEngineDelete(runtime.engine)
    runtime.engine = nil

proc loadExport(runtime: MobaRuntime, name: string): ExportFn =
  ## Copies one function export out of the instance.
  var item: WasmtimeExtern
  if not wasmtimeInstanceExportGet(
      runtime.context, addr runtime.instance,
      name.cstring, name.len.csize_t, addr item):
    raiseRecon("missing export " & name)
  defer:
    wasmtimeExternDelete(addr item)
  if shellWasmtimeExternKind(addr item) != WasmtimeExternFunc:
    raiseRecon("export " & name & " is not a function")
  result.raw = shellWasmtimeExternFunc(addr item)[]
  result.have = true

proc callFn(
  runtime: MobaRuntime, fn: ExportFn, args: openArray[int32],
  nresults: int
): seq[WasmtimeVal] =
  ## Calls one cached export. Results are owned by the caller.
  if not fn.have:
    raiseRecon("export was not cached")
  var
    function = fn.raw
    argBuf: array[4, WasmtimeVal]
    trap: ptr WasmTrap
  if args.len > argBuf.len:
    raiseRecon("too many wasm arguments")
  for i, value in args:
    shellWasmtimeValI32Set(addr argBuf[i], value)
  result.setLen(nresults)
  let
    argPtr =
      if args.len == 0: nil else: addr argBuf[0]
    resPtr =
      if nresults == 0: nil else: addr result[0]
  let error = wasmtimeFuncCall(
    runtime.context, addr function,
    argPtr, args.len.csize_t,
    resPtr, nresults.csize_t, addr trap)
  requireNoError(error, "wasm call")
  requireNoTrap(trap, "wasm call")

proc callVoid(runtime: MobaRuntime, fn: ExportFn, args: openArray[int32]) =
  ## Calls a void export.
  discard runtime.callFn(fn, args, 0)

proc callI32(runtime: MobaRuntime, fn: ExportFn, args: openArray[int32]): int32 =
  ## Calls an i32-returning export.
  var results = runtime.callFn(fn, args, 1)
  shellWasmtimeValI32Get(addr results[0])

proc memoryBytes(runtime: MobaRuntime): tuple[data: ptr uint8, size: int] =
  ## Current linear memory base and length.
  if not runtime.haveMemory:
    raiseRecon("memory export missing")
  result.data = wasmtimeMemoryData(runtime.context, addr runtime.memory)
  result.size = wasmtimeMemoryDataSize(runtime.context, addr runtime.memory).int
  if result.data == nil:
    raiseRecon("wasm memory is nil")

proc readBytes*(runtime: MobaRuntime, offset, length: int): string =
  ## Copies length bytes from wasm memory at offset.
  if offset < 0 or length < 0:
    raiseRecon("negative memory range")
  let mem = runtime.memoryBytes()
  if offset > mem.size or length > mem.size - offset:
    raiseRecon(
      "memory read " & $offset & "+" & $length &
      " exceeds " & $mem.size
    )
  result = newString(length)
  if length > 0:
    copyMem(addr result[0], cast[pointer](cast[uint](mem.data) + offset.uint),
      length)

proc writeBytes(runtime: MobaRuntime, offset: int, data: string) =
  ## Writes data into wasm memory at offset.
  if offset < 0:
    raiseRecon("negative memory offset")
  let mem = runtime.memoryBytes()
  if offset > mem.size or data.len > mem.size - offset:
    raiseRecon(
      "memory write " & $offset & "+" & $data.len &
      " exceeds " & $mem.size
    )
  if data.len > 0:
    copyMem(
      cast[pointer](cast[uint](mem.data) + offset.uint),
      unsafeAddr data[0], data.len
    )

proc writeF32le(dst: var string, offset: int, value: float32) =
  ## Writes one little-endian f32 into dst.
  if offset < 0 or offset + 4 > dst.len:
    raiseRecon("f32 write past action buffer")
  var v = value
  copyMem(addr dst[offset], addr v, 4)

proc writeActions*(
  runtime: MobaRuntime, actions: openArray[array[NumAtns, uint8]]
) =
  ## Writes 10x6 post-clamp actions as f32, matching sim.py set_actions.
  if actions.len != NumAgents:
    raiseRecon("actions must cover 10 heroes")
  var buf = newString(NumAgents * NumAtns * 4)
  for pid in 0 ..< NumAgents:
    for col in 0 ..< NumAtns:
      let raw = int(actions[pid][col])
      if raw < 0 or raw >= ActHigh[col]:
        raiseRecon(
          "hero " & $pid & " col " & $col & " value " & $raw &
          " outside 0 ..< " & $ActHigh[col]
        )
      writeF32le(buf, (pid * NumAtns + col) * 4, float32(raw))
  runtime.writeBytes(int(runtime.actPtr), buf)

proc observations*(runtime: MobaRuntime): seq[string] =
  ## Fresh 10 x 510 observation rows.
  let raw = runtime.readBytes(int(runtime.obsPtr), NumAgents * ObsSize)
  result = newSeq[string](NumAgents)
  for pid in 0 ..< NumAgents:
    let start = pid * ObsSize
    result[pid] = raw[start ..< start + ObsSize]

proc step*(runtime: MobaRuntime) =
  ## One sim tick.
  runtime.callVoid(runtime.fnStep, [])

proc done*(runtime: MobaRuntime): int32 =
  ## Patch-0003 done flag.
  runtime.callI32(runtime.fnDone, [])

proc winner*(runtime: MobaRuntime): int32 =
  ## 0 radiant / 1 dire when done.
  runtime.callI32(runtime.fnWinner, [])

proc tick*(runtime: MobaRuntime): int32 =
  ## Current env.tick.
  runtime.callI32(runtime.fnTick, [])

proc fault*(runtime: MobaRuntime): int32 =
  ## Patch-0004 fault flag.
  runtime.callI32(runtime.fnFault, [])

proc agentStat*(runtime: MobaRuntime, pid, which: int): int32 =
  ## Exported per-hero scoring stat.
  runtime.callI32(runtime.fnStat, [int32(pid), int32(which)])

proc stateDigest*(runtime: MobaRuntime): uint32 =
  ## FNV-1a of hero x/y/health + ancient healths.
  uint32(runtime.callI32(runtime.fnDigest, []))

proc ancientHealth*(runtime: MobaRuntime, team: int): float32 =
  ## Remaining ancient health; 0 when pid == -1.
  var results = runtime.callFn(runtime.fnAncient, [int32(team)], 1)
  bitsToFloat32(shellWasmtimeValI32Get(addr results[0]))

proc newRuntime*(wasm: string, seed: int64): MobaRuntime =
  ## Instantiates one episode, matching MobaSim.__init__.
  if wasm.len == 0:
    raiseRecon("empty wasm module")
  result = MobaRuntime()
  let config = wasmConfigNew()
  if config == nil:
    raiseRecon("wasm_config_new returned nil")
  result.engine = wasmEngineNewWithConfig(config)
  if result.engine == nil:
    raiseRecon("wasm_engine_new_with_config returned nil")
  result.store = wasmtimeStoreNew(result.engine, nil, nil)
  if result.store == nil:
    raiseRecon("wasmtime_store_new returned nil")
  result.context = wasmtimeStoreContext(result.store)
  let wasi = wasiConfigNew()
  if wasi == nil:
    raiseRecon("wasi_config_new returned nil")
  wasiConfigInheritStdout(wasi)
  wasiConfigInheritStderr(wasi)
  requireNoError(
    wasmtimeContextSetWasi(result.context, wasi),
    "wasmtime_context_set_wasi"
  )
  var module: ptr WasmtimeModule
  requireNoError(
    wasmtimeModuleNew(
      result.engine, cast[ptr uint8](unsafeAddr wasm[0]),
      wasm.len.csize_t, addr module
    ),
    "wasmtime_module_new"
  )
  result.module = module
  result.linker = wasmtimeLinkerNew(result.engine)
  if result.linker == nil:
    raiseRecon("wasmtime_linker_new returned nil")
  requireNoError(
    wasmtimeLinkerDefineWasi(result.linker),
    "wasmtime_linker_define_wasi"
  )
  let growthType = wasmFunctypeNew10(wasmValtypeNewI32())
  if growthType == nil:
    raiseRecon("wasm_functype_new_1_0 returned nil")
  defer:
    wasmFuncTypeDelete(growthType)
  const GrowthName = "emscripten_notify_memory_growth"
  requireNoError(
    shellWasmtimeLinkerDefineFunc(
      result.linker, "env", 3, GrowthName, GrowthName.len.csize_t,
      growthType, notifyGrowth, nil
    ),
    "define emscripten_notify_memory_growth"
  )
  var trap: ptr WasmTrap
  requireNoError(
    wasmtimeLinkerInstantiate(
      result.linker, result.context, result.module,
      addr result.instance, addr trap
    ),
    "instantiate"
  )
  requireNoTrap(trap, "instantiate")
  var memItem: WasmtimeExtern
  if not wasmtimeInstanceExportGet(
      result.context, addr result.instance, "memory", 6, addr memItem):
    raiseRecon("missing memory export")
  defer:
    wasmtimeExternDelete(addr memItem)
  if shellWasmtimeExternKind(addr memItem) != WasmtimeExternMemory:
    raiseRecon("memory export has the wrong kind")
  result.memory = shellWasmtimeExternMemory(addr memItem)[]
  result.haveMemory = true
  let initialize = result.loadExport("_initialize")
  result.callVoid(initialize, [])
  result.fnInit = result.loadExport("moba_init")
  result.fnStep = result.loadExport("moba_step")
  result.fnObs = result.loadExport("obs_ptr")
  result.fnAct = result.loadExport("act_ptr")
  result.fnDone = result.loadExport("moba_done")
  result.fnWinner = result.loadExport("moba_winner")
  result.fnTick = result.loadExport("moba_tick")
  result.fnFault = result.loadExport("moba_fault")
  result.fnStat = result.loadExport("agent_stat")
  result.fnDigest = result.loadExport("state_digest")
  result.fnAncient = result.loadExport("ancient_health")
  result.callVoid(result.fnInit, [seedBits(seed), int32(NumAgents)])
  result.obsPtr = result.callI32(result.fnObs, [])
  result.actPtr = result.callI32(result.fnAct, [])
  if result.obsPtr < 0 or result.actPtr < 0:
    raiseRecon("obs_ptr/act_ptr negative")
