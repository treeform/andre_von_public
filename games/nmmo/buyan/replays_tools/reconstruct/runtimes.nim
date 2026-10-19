import "/Users/me/p/coworld-ctf/src/shell/wasmtime_c"

const
  ObsSize = 1707
  MaxAction = 25
  MemoryExport = "memory"
  NotifyGrowthName = "emscripten_notify_memory_growth"

type
  WasiConfig {.importc: "wasi_config_t", header: "wasi.h".} = object
  WasmValType {.importc: "wasm_valtype_t", header: "wasm.h".} = object
  NmmoReconstructionError* = object of CatchableError
  Runtime* = object
    engine: ptr WasmEngine
    store: ptr WasmtimeStore
    context: ptr WasmtimeContext
    module: ptr WasmtimeModule
    linker: ptr WasmtimeLinker
    instance: WasmtimeInstance
    memory: WasmtimeMemory
    numAgents: int

proc wasiConfigNew(): ptr WasiConfig {.importc: "wasi_config_new",
    header: "wasi.h".}
  ## Allocates an empty WASI config.

proc setWasi(ctx: ptr WasmtimeContext;
    wasi: ptr WasiConfig): ptr WasmtimeError
    {.importc: "wasmtime_context_set_wasi", header: "wasmtime.h".}
  ## Installs WASI state and consumes `wasi`.

proc defineWasi(linker: ptr WasmtimeLinker): ptr WasmtimeError
    {.importc: "wasmtime_linker_define_wasi", header: "wasmtime.h".}
  ## Defines WASI imports on `linker`.

proc newI32(): ptr WasmValType {.importc: "wasm_valtype_new_i32",
    header: "wasm.h".}
  ## Allocates an i32 value type.

proc newType1_0(v: ptr WasmValType): ptr WasmFuncType
    {.importc: "wasm_functype_new_1_0", header: "wasm.h".}
  ## Builds a (i32) -> void function type.

proc vecToString(msg: var WasmByteVec): string {.raises: [].} =
  ## Copies a Wasmtime byte vector into a Nim string without a trailing NUL.
  var n = int(msg.size)
  if n > 0:
    let data = cast[ptr UncheckedArray[uint8]](msg.data)
    if data != nil and data[n - 1] == 0:
      dec n
  result = newString(n)
  if n > 0 and msg.data != nil:
    copyMem(addr result[0], msg.data, n)

proc takeError(err: ptr WasmtimeError): string {.raises: [].} =
  ## Takes ownership of `err` and returns its message.
  var msg: WasmByteVec
  wasmtimeErrorMessage(err, addr msg)
  result = vecToString(msg)
  wasmByteVecDelete(addr msg)
  wasmtimeErrorDelete(err)

proc takeTrap(trap: ptr WasmTrap): string {.raises: [].} =
  ## Takes ownership of `trap` and returns its message.
  var msg: WasmByteVec
  wasmTrapMessage(trap, addr msg)
  result = vecToString(msg)
  wasmByteVecDelete(addr msg)
  wasmTrapDelete(trap)

proc raiseIfWasm(err: ptr WasmtimeError; trap: ptr WasmTrap)
    {.raises: [NmmoReconstructionError].} =
  ## Converts a Wasmtime error or trap into `NmmoReconstructionError`.
  if err != nil:
    let msg = takeError(err)
    if trap != nil:
      discard takeTrap(trap)
    raise newException(NmmoReconstructionError, msg)
  if trap != nil:
    raise newException(NmmoReconstructionError, takeTrap(trap))

proc fail(msg: string) {.raises: [NmmoReconstructionError], noinline.} =
  ## Raises `NmmoReconstructionError` with `msg`.
  raise newException(NmmoReconstructionError, msg)

proc notifyMemoryGrowth(env: pointer; caller: ptr WasmtimeCaller;
    args: ptr WasmtimeConstVal; nargs: csize_t;
    results: ptr WasmtimeVal; nresults: csize_t): ptr WasmTrap
    {.cdecl, raises: [].} =
  ## No-op host stub for Emscripten memory-growth notification.
  discard env
  discard caller
  discard args
  discard nargs
  discard results
  discard nresults
  result = nil

proc writeF32Le(dst: ptr UncheckedArray[uint8]; offset: int;
    value: float32) {.raises: [].} =
  ## Writes `value` as little-endian IEEE-754 bytes at `offset`.
  let bits = cast[uint32](value)
  dst[offset] = uint8(bits and 0xff'u32)
  dst[offset + 1] = uint8((bits shr 8) and 0xff'u32)
  dst[offset + 2] = uint8((bits shr 16) and 0xff'u32)
  dst[offset + 3] = uint8((bits shr 24) and 0xff'u32)

proc checkBounds(offset, length: int; size: csize_t)
    {.raises: [NmmoReconstructionError].} =
  ## Rejects a memory range that is negative or exceeds `size`.
  if offset < 0 or length < 0:
    fail("negative memory range")
  let
    off = uint64(offset)
    len = uint64(length)
    cap = uint64(size)
  if off > cap or len > cap - off:
    fail("memory out of bounds")

proc close*(runtime: var Runtime) {.raises: [].} =
  ## Releases Wasmtime resources owned by `runtime` exactly once.
  if runtime.linker != nil:
    wasmtimeLinkerDelete(runtime.linker)
    runtime.linker = nil
  if runtime.store != nil:
    wasmtimeStoreDelete(runtime.store)
    runtime.store = nil
  runtime.context = nil
  if runtime.module != nil:
    wasmtimeModuleDelete(runtime.module)
    runtime.module = nil
  if runtime.engine != nil:
    wasmEngineDelete(runtime.engine)
    runtime.engine = nil
  reset(runtime.instance)
  reset(runtime.memory)

proc callRaw(runtime: var Runtime; name: string; args: openArray[int32];
    results: ptr WasmtimeVal; nresults: csize_t)
    {.raises: [NmmoReconstructionError].} =
  ## Looks up export `name` and calls it with i32 arguments.
  if runtime.context == nil:
    fail("runtime is closed")
  var item: WasmtimeExtern
  if not wasmtimeInstanceExportGet(runtime.context, addr runtime.instance,
      name.cstring, csize_t(name.len), addr item):
    fail("missing export: " & name)
  if shellWasmtimeExternKind(addr item) != WasmtimeExternFunc:
    wasmtimeExternDelete(addr item)
    fail("export is not a function: " & name)
  var fn = shellWasmtimeExternFunc(addr item)[]
  wasmtimeExternDelete(addr item)
  var
    vals = newSeq[WasmtimeVal](args.len)
    trap: ptr WasmTrap = nil
  for i, value in args:
    shellWasmtimeValI32Set(addr vals[i], value)
  let
    argsPtr = if vals.len == 0: nil else: addr vals[0]
    err = wasmtimeFuncCall(runtime.context, addr fn, argsPtr,
        csize_t(vals.len), results, nresults, addr trap)
  raiseIfWasm(err, trap)

proc callI32*(runtime: var Runtime; name: string;
    args: openArray[int32] = []): int32
    {.raises: [NmmoReconstructionError].} =
  ## Calls exported `name` with i32 args and returns one i32.
  var resultVal: WasmtimeVal
  callRaw(runtime, name, args, addr resultVal, 1.csize_t)
  result = shellWasmtimeValI32Get(addr resultVal)

proc callVoid*(runtime: var Runtime; name: string;
    args: openArray[int32] = []) {.raises: [NmmoReconstructionError].} =
  ## Calls exported `name` with i32 args and no results.
  callRaw(runtime, name, args, nil, 0.csize_t)

proc bindNotifyGrowth(linker: ptr WasmtimeLinker)
    {.raises: [NmmoReconstructionError].} =
  ## Defines `env.emscripten_notify_memory_growth` as a no-op.
  let funcType = newType1_0(newI32())
  if funcType == nil:
    fail("wasm_functype_new_1_0 failed")
  let err = shellWasmtimeLinkerDefineFunc(linker, "env", 3.csize_t,
      NotifyGrowthName, csize_t(NotifyGrowthName.len), funcType,
      notifyMemoryGrowth, nil)
  wasmFuncTypeDelete(funcType)
  raiseIfWasm(err, nil)

proc loadMemory(runtime: var Runtime)
    {.raises: [NmmoReconstructionError].} =
  ## Copies the instance `memory` export handle into `runtime`.
  var item: WasmtimeExtern
  if not wasmtimeInstanceExportGet(runtime.context, addr runtime.instance,
      MemoryExport, csize_t(MemoryExport.len), addr item):
    fail("missing memory export")
  if shellWasmtimeExternKind(addr item) != WasmtimeExternMemory:
    wasmtimeExternDelete(addr item)
    fail("memory export is not memory")
  runtime.memory = shellWasmtimeExternMemory(addr item)[]
  wasmtimeExternDelete(addr item)

proc setupRuntime(runtime: var Runtime; wasmBytes: string; seed: uint32)
    {.raises: [NmmoReconstructionError].} =
  ## Compiles, instantiates, and initializes the NMMO module.
  let config = wasmConfigNew()
  if config == nil:
    fail("wasm_config_new failed")
  runtime.engine = wasmEngineNewWithConfig(config)
  if runtime.engine == nil:
    fail("wasm_engine_new_with_config failed")
  var module: ptr WasmtimeModule = nil
  let moduleErr = wasmtimeModuleNew(runtime.engine,
      cast[ptr uint8](cstring(wasmBytes)), csize_t(wasmBytes.len),
      addr module)
  raiseIfWasm(moduleErr, nil)
  runtime.module = module
  runtime.store = wasmtimeStoreNew(runtime.engine, nil, nil)
  if runtime.store == nil:
    fail("wasmtime_store_new failed")
  runtime.context = wasmtimeStoreContext(runtime.store)
  if runtime.context == nil:
    fail("wasmtime_store_context failed")
  let wasi = wasiConfigNew()
  if wasi == nil:
    fail("wasi_config_new failed")
  raiseIfWasm(setWasi(runtime.context, wasi), nil)
  runtime.linker = wasmtimeLinkerNew(runtime.engine)
  if runtime.linker == nil:
    fail("wasmtime_linker_new failed")
  raiseIfWasm(defineWasi(runtime.linker), nil)
  bindNotifyGrowth(runtime.linker)
  var trap: ptr WasmTrap = nil
  let instErr = wasmtimeLinkerInstantiate(runtime.linker, runtime.context,
      runtime.module, addr runtime.instance, addr trap)
  raiseIfWasm(instErr, trap)
  loadMemory(runtime)
  callVoid(runtime, "_initialize")
  callVoid(runtime, "nmmo_init",
      [cast[int32](seed), int32(runtime.numAgents)])
  let obs = callI32(runtime, "obs_size")
  if obs != ObsSize:
    fail("obs_size is " & $obs & ", expected " & $ObsSize)

proc newRuntime*(wasmBytes: string; seed: uint32; numAgents: int): Runtime
    {.raises: [NmmoReconstructionError].} =
  ## Instantiates the NMMO Wasm module for recorded-replay hosting.
  if numAgents < 0 or numAgents > int32.high:
    fail("invalid numAgents")
  result.numAgents = numAgents
  try:
    setupRuntime(result, wasmBytes, seed)
  except NmmoReconstructionError as error:
    close(result)
    raise error
  except CatchableError as err:
    close(result)
    raise newException(NmmoReconstructionError, err.msg)

proc readBytes*(runtime: var Runtime; offset, length: int): string
    {.raises: [NmmoReconstructionError].} =
  ## Copies `length` bytes from Wasm memory at `offset`.
  if runtime.context == nil:
    fail("runtime is closed")
  let
    data = wasmtimeMemoryData(runtime.context, addr runtime.memory)
    size = wasmtimeMemoryDataSize(runtime.context, addr runtime.memory)
  checkBounds(offset, length, size)
  result = newString(length)
  if length > 0:
    let bytes = cast[ptr UncheckedArray[uint8]](data)
    copyMem(addr result[0], addr bytes[offset], length)

proc writeActions*(runtime: var Runtime; actions: openArray[int])
    {.raises: [NmmoReconstructionError].} =
  ## Writes float32 actions into Wasm memory at `act_ptr()`.
  if actions.len != runtime.numAgents:
    fail("action count is " & $actions.len & ", expected " &
        $runtime.numAgents)
  for action in actions:
    if action < 0 or action > MaxAction:
      fail("action " & $action & " is outside 0..25")
  if actions.len > (int.high div 4):
    fail("action buffer is too large")
  let
    base = callI32(runtime, "act_ptr")
    off = uint64(cast[uint32](base))
    byteLen = uint64(actions.len) * 4'u64
    data = wasmtimeMemoryData(runtime.context, addr runtime.memory)
    cap = uint64(wasmtimeMemoryDataSize(runtime.context,
        addr runtime.memory))
  if data == nil or off > cap or byteLen > cap - off:
    fail("act buffer out of bounds")
  let bytes = cast[ptr UncheckedArray[uint8]](data)
  for i, action in actions:
    writeF32Le(bytes, int(off) + i * 4, float32(action))
