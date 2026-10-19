# NMMO hosted replay and log extraction

Implement and verify Nim tools only. All new files must remain under
`games/nmmo/buyan/replays_tools/`. Read the supplied repo AGENTS instructions,
`tools/workers.md`, and `sims/nmmo/AGENTS.md` before inspecting the sim.
The shared repo already contains unrelated edits: do not touch them.

Write `replays.nim`, `extract.nim`, and `tests/tests.nim`. The parser and
report logic go in the library, the CLI accepts one or more binary hosted
replay files and prints one JSON summary per replay. Do not use
`when isMainModule`. Nim only, no Python/bash/JavaScript helper scripts.

Read `sims/nmmo/docs/PROTOCOL.md` and
`sims/nmmo/server/cogame_nmmo/replay.py` for the binary NMMO v1 format.
The header contains config.players, config.heroes_per_seat, tick_count,
result, and sim_wasm_sha256; body is tick-major one post-clamp action byte
per agent. Validate magic/version/header shape/length/counts/action range.
Map JSON and IO failures to `NmmoReplayError` with useful messages.

Report per seat: index, player name, number of agents/ticks, action count
and fraction for all 26 action ids, groups walk 0..3, run 22..25, attack 5,
noop 4, inventory keys 8..16, buy 20, sell 21, other 6/7/17/18/19.
Also report adjacent repeated attack count, attack burst count, longest
attack burst, longest same movement action run, first tick each group
activated, and header result fields preserved. Counts of adjacent attacks
must be per agent and must never bridge seat/agent boundaries.

Name groups accurately: inventory keys can select a market entry/price;
actions alone cannot establish a successful attack, harvest, item use,
market purchase/sale, traversal distance, or score delta. Include explicit
evidence limitation text and observationsAvailable=false.

Add a log extractor if a practical existing hosted log example is present
under `hosted/`: it should summarize explicit strategy markers from JSONL
with `strategy` string, `activated` bool, optional `tick` and `agent`,
counting activated events and distinct activated ticks per agent. Expose a
separate CLI command or program. If there are no logs, implement this small
generic parser against synthetic isolation fixtures, but clearly report
synthetic tests as non-scoring evidence.

Synthetic tests (doAssert, no framework) must verify two seats with two
agents, correct tick-major indexing, action groups, no accidental attack
streak carryover across agents, malformed/truncated file rejection, and
marker counts. Tests are parser isolation only: NEVER run local games.

Run `nim check games/nmmo/buyan/replays_tools/extract.nim` then
`nim r games/nmmo/buyan/replays_tools/tests/tests.nim`. Compile the CLI and
run it on actual hosted files if they arrive under `hosted/`. Add a terse
`worker_report.md` with changed files, validation commands, limitations.
Use normal repo Nim style, 2 spaces, concise doc comments on every proc.

DO NOT commit, push, docker build, upload, submit, run local games, call
coworld commands, touch sims/vendor source, or edit any parent bot files.
