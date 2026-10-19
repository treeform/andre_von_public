# Write one Nim hosted replay extractor

Only create reconstruct.nim in
/Users/me/p/andre_von_auto/games/nmmo/buyan/replays_tools/reconstruct/ .
Nim code only. Native read_file/search_replace only; never execute anything
or work around unavailable terminal. Supervisor will compile/run/review.
Read exact file /Users/me/p/andre_von_auto/games/nmmo/buyan/replays_tools/reconstruct/task.md
for metric/schema specification, then exact file
/Users/me/p/andre_von_auto/games/nmmo/buyan/replays_tools/reconstruct/review_corrections.md
for source caveats. DO NOT read their source references: all needed details
already verified by supervisor and supplied here. Do not recursively inspect
directories. Do not read full sim/header/server sources. Write immediately.

Separate Grok now implements runtimes.nim; don't read/edit it. Pinned API:
Runtime explicit object; NmmoReconstructionError object of CatchableError;
newRuntime(wasmBytes:string,seed:uint32,numAgents:int):Runtime;
close(runtime:var Runtime);
callI32(runtime:var Runtime,name:string,args:openArray[int32]=[]):int32;
callVoid(runtime:var Runtime,name:string,args:openArray[int32]=[]);
readBytes(runtime:var Runtime,offset,length:int):string;
writeActions(runtime:var Runtime,actions:openArray[int]).
newRuntime invokes _initialize and nmmo_init and checks obs_size==1707.
Import ../replays existing pinned API described in task. Import
crunchy/sha256 (sha256(data:string):array[32,uint8]) for exact wasm hash;
supervisor adds compile paths. Hex lowercase via each byte.toHex(2).

CLI reconstruct <wasm> <hosted.replay> <output.json>. Only replay recorded
actions. Runtime read API exports: obs_ptr,term_ptr,nmmo_tick,nmmo_fault,
state_digest integer noargs; agent_stat(pid,which) returns int where
0 cumulativeMin,1 deaths,2 combat,3 profession,4 currentLifeMin,5 gold,
6 timeAlive,7 hp; nmmo_step void noargs.
Runtime initialization default legacy obs; self scalars/stats invariant to
clean opt-in; never use terrain/entity bytes for claims. No score export.

Read all six final hosted agent stats EXACTLY via header.result.agent_stats;
match state_digest as uint32 bitpattern and final_tick == replay.tickCount.
Validate expected JSON types. Digest/hash/stats mismatch -> fail, no report.
Only after exact proof output verified JSON task describes. If output exists,
do not truncate until proof; exception error reporting can quit1. Runtime
cleanup defer mandatory. IO/parsing exceptions mapped NmmoReconstructionError.

Please use plain concise data structs and explicit loops. Self snapshot
contains stats+47bytes scalars. Read obs memory full numAgents*1707 once
per tick (not per agent); stats per agent. Track fixed20 ring of per-step
records (pre self,action,post hp,terminal,runNoAnim,attackAnimation,
combat); death report includes preceding20. Avoid large generic JSON logic.
Only report attack_animation, since find_target sets animation before
target lookup. run/walk animation confirms move after destination checks
only for alive, nonterminal, preui0 intervals. Use names task metric schema.
No hypothesis keep/discard or local scoring.

No when isMainModule. Main proc then main() at top level. Doc each proc,
group let/var, Nim 2spaces, <=80cols. Write file now; report checks for
supervisor, don't execute them.
