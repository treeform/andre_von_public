## Narrow Wasmtime v48 C API for hosted MOBA reconstruction.
## Reuses the existing coworld-ctf wasmtime_shim.h helpers and the
## unpacked wasmtime-v48.0.1 C API. WASI + emscripten growth only.

import std/os

const
  WasmtimeHeader* = "wasmtime_shim.h"
  DefaultWasmtimeCapi =
    "/Users/me/p/andre_von_auto/games/nmmo/buyan/" &
    "replays_tools/reconstruct/deps/" &
    "wasmtime-v48.0.1-aarch64-macos-c-api"

proc wasmtimeCapiRoot(): string =
  ## Compile-time Wasmtime C API root.
  let env = getEnv("WASMTIME_C_API")
  if env.len > 0: env else: DefaultWasmtimeCapi

const WasmtimeCapiRoot = static: wasmtimeCapiRoot()

{.passC: "-I" & currentSourcePath().parentDir.}
{.passC: "-I/Users/me/p/coworld-ctf/src/shell".}
{.passC: "-I" & WasmtimeCapiRoot / "include".}
{.passL: "-L" & WasmtimeCapiRoot / "lib".}
{.passL: "-lwasmtime".}
{.passL: "-Wl,-rpath," & WasmtimeCapiRoot / "lib".}

type
  WasmConfig* {.importc: "wasm_config_t", header: WasmtimeHeader.} = object
  WasmEngine* {.importc: "wasm_engine_t", header: WasmtimeHeader.} = object
  WasmFuncType* {.importc: "wasm_functype_t", header: WasmtimeHeader.} = object
  WasmValType* {.importc: "wasm_valtype_t", header: WasmtimeHeader.} = object
  WasmTrap* {.importc: "wasm_trap_t", header: WasmtimeHeader.} = object
  WasiConfig* {.importc: "wasi_config_t", header: WasmtimeHeader.} = object
  WasmtimeContext* {.importc: "wasmtime_context_t",
      header: WasmtimeHeader.} = object
  WasmtimeError* {.importc: "wasmtime_error_t",
      header: WasmtimeHeader.} = object
  WasmtimeExtern* {.importc: "wasmtime_extern_t",
      header: WasmtimeHeader.} = object
  WasmtimeFunc* {.importc: "wasmtime_func_t",
      header: WasmtimeHeader.} = object
  WasmtimeInstance* {.importc: "wasmtime_instance_t",
      header: WasmtimeHeader.} = object
  WasmtimeModule* {.importc: "wasmtime_module_t",
      header: WasmtimeHeader.} = object
  WasmtimeLinker* {.importc: "wasmtime_linker_t",
      header: WasmtimeHeader.} = object
  WasmtimeMemory* {.importc: "wasmtime_memory_t",
      header: WasmtimeHeader.} = object
  WasmtimeCaller* {.importc: "wasmtime_caller_t",
      header: WasmtimeHeader.} = object
  WasmtimeStore* {.importc: "wasmtime_store_t",
      header: WasmtimeHeader.} = object
  WasmtimeVal* {.importc: "wasmtime_val_t", header: WasmtimeHeader.} = object
  WasmtimeConstVal* {.importc: "const wasmtime_val_t",
      header: WasmtimeHeader.} = object
  WasmByteVec* {.importc: "wasm_byte_vec_t", header: WasmtimeHeader,
      bycopy.} = object
    size*: csize_t
    data*: ptr uint8
  WasmtimeCallback* = proc(env: pointer; caller: ptr WasmtimeCaller;
      args: ptr WasmtimeConstVal; nargs: csize_t; results: ptr WasmtimeVal;
      nresults: csize_t): ptr WasmTrap {.cdecl.}

const
  WasmtimeExternFunc* = 0'u8
  WasmtimeExternMemory* = 3'u8

proc wasmConfigNew*(): ptr WasmConfig {.importc: "wasm_config_new",
    header: WasmtimeHeader.}
proc wasmEngineNewWithConfig*(config: ptr WasmConfig): ptr WasmEngine {.
    importc: "wasm_engine_new_with_config", header: WasmtimeHeader.}
proc wasmEngineDelete*(engine: ptr WasmEngine) {.importc: "wasm_engine_delete",
    header: WasmtimeHeader.}
proc wasmtimeStoreNew*(engine: ptr WasmEngine; data: pointer;
    finalizer: pointer): ptr WasmtimeStore {.importc: "wasmtime_store_new",
    header: WasmtimeHeader.}
proc wasmtimeStoreContext*(store: ptr WasmtimeStore): ptr WasmtimeContext {.
    importc: "wasmtime_store_context", header: WasmtimeHeader.}
proc wasmtimeStoreDelete*(store: ptr WasmtimeStore) {.
    importc: "wasmtime_store_delete", header: WasmtimeHeader.}
proc wasmtimeModuleNew*(engine: ptr WasmEngine; bytes: ptr uint8;
    size: csize_t; module: ptr ptr WasmtimeModule): ptr WasmtimeError {.
    importc: "wasmtime_module_new", header: WasmtimeHeader.}
proc wasmtimeModuleDelete*(module: ptr WasmtimeModule) {.
    importc: "wasmtime_module_delete", header: WasmtimeHeader.}
proc wasmtimeLinkerNew*(engine: ptr WasmEngine): ptr WasmtimeLinker {.
    importc: "wasmtime_linker_new", header: WasmtimeHeader.}
proc wasmtimeLinkerDelete*(linker: ptr WasmtimeLinker) {.
    importc: "wasmtime_linker_delete", header: WasmtimeHeader.}
proc wasmtimeLinkerDefineWasi*(linker: ptr WasmtimeLinker): ptr WasmtimeError {.
    importc: "wasmtime_linker_define_wasi", header: WasmtimeHeader.}
proc shellWasmtimeLinkerDefineFunc*(linker: ptr WasmtimeLinker;
    module: cstring; moduleLen: csize_t; name: cstring; nameLen: csize_t;
    functionType: ptr WasmFuncType; callback: WasmtimeCallback;
    data: pointer): ptr WasmtimeError {.
    importc: "shell_wasmtime_linker_define_func", header: WasmtimeHeader.}
proc wasmtimeLinkerInstantiate*(linker: ptr WasmtimeLinker;
    context: ptr WasmtimeContext; module: ptr WasmtimeModule;
    instance: ptr WasmtimeInstance; trap: ptr ptr WasmTrap): ptr WasmtimeError {.
    importc: "wasmtime_linker_instantiate", header: WasmtimeHeader.}
proc wasmtimeInstanceExportGet*(context: ptr WasmtimeContext;
    instance: ptr WasmtimeInstance; name: cstring; nameLen: csize_t;
    item: ptr WasmtimeExtern): bool {.importc: "wasmtime_instance_export_get",
    header: WasmtimeHeader.}
proc wasmtimeExternDelete*(item: ptr WasmtimeExtern) {.
    importc: "wasmtime_extern_delete", header: WasmtimeHeader.}
proc wasmtimeFuncCall*(context: ptr WasmtimeContext; function: ptr WasmtimeFunc;
    args: ptr WasmtimeVal; nargs: csize_t; results: ptr WasmtimeVal;
    nresults: csize_t; trap: ptr ptr WasmTrap): ptr WasmtimeError {.
    importc: "wasmtime_func_call", header: WasmtimeHeader.}
proc wasmtimeMemoryData*(context: ptr WasmtimeContext;
    memory: ptr WasmtimeMemory): ptr uint8 {.importc: "wasmtime_memory_data",
    header: WasmtimeHeader.}
proc wasmtimeMemoryDataSize*(context: ptr WasmtimeContext;
    memory: ptr WasmtimeMemory): csize_t {.
    importc: "wasmtime_memory_data_size", header: WasmtimeHeader.}
proc wasmFuncTypeDelete*(functionType: ptr WasmFuncType) {.
    importc: "wasm_functype_delete", header: WasmtimeHeader.}
proc wasmValtypeNewI32*(): ptr WasmValType {.importc: "wasm_valtype_new_i32",
    header: WasmtimeHeader.}
proc wasmFunctypeNew10*(p: ptr WasmValType): ptr WasmFuncType {.
    importc: "wasm_functype_new_1_0", header: WasmtimeHeader.}
proc wasiConfigNew*(): ptr WasiConfig {.importc: "wasi_config_new",
    header: WasmtimeHeader.}
proc wasiConfigInheritStdout*(config: ptr WasiConfig) {.
    importc: "wasi_config_inherit_stdout", header: WasmtimeHeader.}
proc wasiConfigInheritStderr*(config: ptr WasiConfig) {.
    importc: "wasi_config_inherit_stderr", header: WasmtimeHeader.}
proc wasmtimeContextSetWasi*(context: ptr WasmtimeContext;
    wasi: ptr WasiConfig): ptr WasmtimeError {.
    importc: "wasmtime_context_set_wasi", header: WasmtimeHeader.}
proc wasmtimeErrorMessage*(error: ptr WasmtimeError;
    output: ptr WasmByteVec) {.importc: "wasmtime_error_message",
    header: WasmtimeHeader.}
proc wasmtimeErrorDelete*(error: ptr WasmtimeError) {.
    importc: "wasmtime_error_delete", header: WasmtimeHeader.}
proc wasmTrapMessage*(trap: ptr WasmTrap; output: ptr WasmByteVec) {.
    importc: "wasm_trap_message", header: WasmtimeHeader.}
proc wasmTrapDelete*(trap: ptr WasmTrap) {.importc: "wasm_trap_delete",
    header: WasmtimeHeader.}
proc wasmByteVecDelete*(bytes: ptr WasmByteVec) {.
    importc: "wasm_byte_vec_delete", header: WasmtimeHeader.}
proc shellWasmtimeValI32Set*(value: ptr WasmtimeVal; number: int32) {.
    importc: "shell_wasmtime_val_i32_set", header: WasmtimeHeader.}
proc shellWasmtimeValI32Get*(value: ptr WasmtimeVal): int32 {.
    importc: "shell_wasmtime_val_i32_get", header: WasmtimeHeader.}
proc shellWasmtimeExternKind*(item: ptr WasmtimeExtern): uint8 {.
    importc: "shell_wasmtime_extern_kind", header: WasmtimeHeader.}
proc shellWasmtimeExternFunc*(item: ptr WasmtimeExtern): ptr WasmtimeFunc {.
    importc: "shell_wasmtime_extern_func", header: WasmtimeHeader.}
proc shellWasmtimeExternMemory*(item: ptr WasmtimeExtern): ptr WasmtimeMemory {.
    importc: "shell_wasmtime_extern_memory", header: WasmtimeHeader.}
