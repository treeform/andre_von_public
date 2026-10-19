# Recorded hosted replay reconstruction

You are Grok, the Nim implementation worker. Write files now using only
read_file and search_replace. No terminal execution or workaround, no
Python, shell scripts, C or any other new code. Supervisor runs Nim checks.
All new files ONLY in this task directory. No source edits elsewhere.

Read /Users/me/p/AGENTS.md for Nim style and
/Users/me/p/andre_von_auto/sims/nmmo/AGENTS.md. The user prohibits local
games for score. This tool may ONLY feed recorded hosted replay actions,
to recover behavior. No alternative actions, policy runs, candidate scores,
local score comparisons, network, CPUX or submission. All outputs explicitly
state no scoring evidence. Require the replay's exact wasm sha256 and final
hosted state_digest match before writing any observation-truth output.

Sources to read:
- /Users/me/p/andre_von_auto/sims/nmmo/server/cogame_nmmo/sim.py
- /Users/me/p/andre_von_auto/sims/nmmo/sim/shim.c
- /Users/me/p/andre_von_auto/sims/nmmo/players/scripted_player.py (offsets).
- /Users/me/p/andre_von_auto/sims/nmmo/vendor/upstream/nmmo3.h
  (move, attack, c_step, compute_all_obs only needed sections).
- /Users/me/p/coworld-ctf/src/shell/wasmtime_c.nim (reuse/import existing).
- /Users/me/p/coworld-ctf/src/shell/wasmtime_shim.h (existing header only).
- deps/wasmtime-v48.0.1-aarch64-macos-c-api/include/{wasm.h,wasi.h,
  wasmtime.h,wasmtime/linker.h,wasmtime/store.h} as needed.

Source commit pinned 96d4ce5a2d279dfb37f252366fa6209645c79a0c.
Supervisor obtains deployed nmmo3_sim.wasm; don't compile simulator.
Existing Wasmtime library is available under deps directory here, v48.0.1,
archive SHA256 9e3c636ed487a41026ff76388c5fa6f3a48ea0968408d033ed4b5e8082c20d69.
Compiler env WASMTIME_C_API will be set to that root by supervisor.
Import existing absolute Nim binding. New helper C API declarations are
Nim importc with header wasmtime.h, wasm.h or wasi.h; NO new C/header/emit.
Reuse existing shim i32 setters/getters and extern accessors. Extend WASI
bindings needed: wasi_config_new, wasmtime_context_set_wasi,
wasmtime_linker_define_wasi, optional inherited output. For emscripten
notify_memory_growth use no-op Nim cdecl callback and function type via
existing header static inline wasm_valtype_new_i32 and
wasm_functype_new_1_0. Correct cleanup on failure and success.

Pinned replay parser another Grok is writing in ../replays.nim:
Replay exports header:JsonNode, body:string, numAgents:int, tickCount:int,
heroesPerSeat:int; loadReplay(path):Replay,
action(replay,tick,agent):int. Import it, do not edit it. If not present yet,
write against that interface. Header config.seed int; sim_wasm_sha256 string;
result has state_digest uint32 as JSON int, final_tick int, agent_stats
array (cum_min_comb_prof,deaths,comb_lvl,prof_lvl,gold,time_alive).

Files:
- runtimes.nim: narrow explicit runtime object and procs newRuntime,
  close, callI32(name,args), callVoid(name,args), readBytes, writeActions.
  Persistent exports can be cached data table; memory bounds checked.
  Initialize exactly sim.py: WASI, memory-growth stub, _initialize,
  nmmo_init(seed bit pattern,numAgents), obs_size==1707. Never reset later.
  Exceptions all NmmoReconstructionError; no silent traps/faults.
- reconstruct.nim: CLI reconstruct <wasm> <hosted.replay> <output.json>.
  Use crunchy/sha256 already installed to hash wasm in Nim, lower hex.
  Compile path supervisor supplies crunchy. Reject hash mismatch immediately.
  Replay current baseline actions only, no generated actions. Before each
  action snapshot stat hp/comb/prof/gold/time_alive and 1707-byte obs, after
  action snapshot stats/obs/terminals. Replay invariant tick follows index,
  nmmo_fault stays 0. Final tick + digest + all six exported end stats MUST
  exactly equal hosted result or raise without writing output.
  Runtime seed from config, mask to uint32 bit pattern.
- usage.md: commands, proof boundaries, meaning of each metric.

Behavior summaries by agent pid and config player names (seat=pid div h):
alive_ticks (pre hp>0), action histogram, attack_issued and attack_animation
(post anim 2/3/4, pre alive, terminal false, pre ui play), attack_no_anim,
IMPORTANT: find_target sets attack anim BEFORE checking a target exists!
Never call animation proof attack_fired or attack hit. It proves only
the attack-target-search branch executed, not contact or damage.
run_issued and run_fired (post anim==6 same validity guards), run_no_anim,
walk_issued/fired (0..3/anim1). Describe no_anim as no matching movement
animation, not inferred coordinates. Actually anim is set only after
destination checks for movement. Track max consecutive failed-move actions,
reset streak on nonmove, valid success, death. No uncertain r/c guesses.
hp_loss_ticks/net_hp_lost for pre alive and post hp<pre hp; stats are exact
but net HP delta isn't raw attack damage (regen/healing can offset it).
combat_ticks from observation scalar +12; naked/tool_held_ticks;
inventory_full_ticks and max_inventory_occupied; profession/combat gains
only within nonterminal live intervals; time_to_first_tool_held;
gold/inventory/equipment changes as summaries. Tool id nonzero %17==6.
Self scalars offset1650: anim4,hp5,comb1,prof7,ui8,in_combat12,
equipment13 (helm,chest,legs,held,gem), inventory18..29.

Death records for every terminal: tick_after_step, cause attack if hp==0
else stagnation (shim documented), pre hp/comb/prof/gold/time_alive,
pre equipment/inventory, last 20 issued actions; preceding 20 ticks
hp_loss_ticks/net_hp_lost, run failure count, attack animation count,
combat ticks. Bound history at 20; include simple per-agent totals by
death cause. Terminal and hp stats are authoritative; include appropriate
limitation about legacy entity-byte staleness, and do not report nearby
enemy liveness from stale obs alone. If debug_nearby needed later can add.

Output includes source=softmax-hosted-replay-reconstruction,
scoring_evidence=false, replay_path, wasm_path, wasm_sha256,
verified_wasm_hash=true, hosted_state_digest, reconstructed_state_digest,
verified_state_digest=true, verified_end_stats=true, tick_count, agents.
No score field, no local winner/rank/delta. Output only after full match.
Use data oriented flat records; doc comment every proc, max4 lines,
no when isMainModule. All parsing/IO failures mapped to library error.

Stop after writing files and reviewing. Report supervisor commands. Do not
try terminal or external execution through any other tool.
