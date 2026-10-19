# Write one small Nim runtime file now

Your task is only create
/Users/me/p/andre_von_auto/games/nmmo/buyan/replays_tools/reconstruct/runtimes.nim.
Use read_file and search_replace only. No terminal/no other execution routes,
no C/JS/Python/shell/new languages. Every new code line Nim. Supervisor runs
nim check and verifies. Do not create extractor yet. Do not read large sim
or server sources. Below is full needed runtime specification. Read only
/Users/me/p/coworld-ctf/src/shell/wasmtime_c.nim and maybe exact short relevant
Wasmtime header sections if needed, no full directory inventory.

Import that existing absolute Wasmtime Nim module; it uses existing shim
header with i32 setters/getters, externKind/externFunc/externMemory wrappers.
WASMTIME_C_API env at compilation points to local deps root:
/Users/me/p/andre_von_auto/games/nmmo/buyan/replays_tools/reconstruct/deps/wasmtime-v48.0.1-aarch64-macos-c-api
Don't change that source or create C. More bindings in Nim importc from
existing headers only:
type WasiConfig {.importc:"wasi_config_t",header:"wasi.h".}=object
type WasmValType {.importc:"wasm_valtype_t",header:"wasm.h".}=object
proc wasiConfigNew():ptr WasiConfig importc wasi_config_new header wasi.h
proc setWasi(ctx:ptr WasmtimeContext,wasi:ptr WasiConfig):ptr WasmtimeError
  importc wasmtime_context_set_wasi header wasmtime.h (consumes config).
proc defineWasi(linker:ptr WasmtimeLinker):ptr WasmtimeError
  importc wasmtime_linker_define_wasi header wasmtime.h.
proc newI32():ptr WasmValType importc wasm_valtype_new_i32 header wasm.h
proc newType1_0(v:ptr WasmValType):ptr WasmFuncType
  importc wasm_functype_new_1_0 header wasm.h (existing inline).

Exports:
NmmoReconstructionError* = object of CatchableError.
Runtime* explicit object engine,store,context,module,linker,instance,memory,
cache optional, numAgents. By value fields same opaque C-import types as
existing module. close*(runtime:var Runtime) cleans each resource exactly
once then nil fields. Partial initialization closes correctly on exception.
newRuntime*(wasmBytes:string,seed:uint32,numAgents:int):Runtime
callI32*(runtime:var Runtime,name:string,args:openArray[int32]=[]):int32
callVoid*(runtime:var Runtime,name:string,args:openArray[int32]=[])
readBytes*(runtime:var Runtime,offset,length:int):string (copy,bounds check)
writeActions*(runtime:var Runtime,actions:openArray[int]) writes float32
  into wasm act_ptr() with bounds and len==numAgents, each action0..25.

Initialization exactly:
config=wasmConfigNew(), engine=wasmEngineNewWithConfig(config);
wasmtimeModuleNew(engine,wasmBytes,len,&module), storeNew, context,
setWasi(context,wasiConfigNew()), linkerNew, defineWasi(linker).
Nim no-op {.cdecl.} WasmtimeCallback signature exactly existing module:
emscripten_notify_memory_growth has (i32)->void. Build type newType1_0(newI32),
shellWasmtimeLinkerDefineFunc(linker,"env",3,
"emscripten_notify_memory_growth",31,type,callback,nil); free type after.
Instantiate; trap/error always converted to NmmoReconstructionError with
message and deleted. Run _initialize(), nmmo_init(seed signed bitpattern,
numAgents). Check obs_size()==1707. Get memory export after instantiate.
No reset, no policy, no game action execution inside constructor after init.

call functions: look up export by name, check WasmtimeExternFunc, call using
WasmtimeVal args and existing i32 setter. Results requested0 or1. Error/trap
message ownership obeyed. Copy memory handle and clean extern wrapper.
Always bounds-check offsets/length avoiding overflow; get current memory
data and size each time. write actions uses cast uint32 float32 bytes
explicitly little endian so wasm byte format never native assumption.

This is read-only recorded replay hosting later; never generates actions
and no local score evidence. No functions for score/reset/alternative policy.

Follow Nim: 2-space indent, camelCase vars/procs, PascalCase types/consts,
group adjacent let/var, <=80 cols, one-line doc comments each proc, no
when isMainModule, no module section comments. Explicit raises when feasible
without drowning code in broad catch errors. Native errors mapped library
error and propagated. Write file immediately then concise report; no repeat
source reading or whole repository search.
