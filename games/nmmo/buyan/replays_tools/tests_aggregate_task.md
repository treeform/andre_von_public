# Validate parser and aggregate hosted action patterns

The supervisor ran `nim check .../extract.nim` and `nim c` successfully,
then extracted 10 current hosted baseline and 16 historical replays.
Outputs are `current_baseline/actions.jsonl` and `hosted/actions.jsonl`.

Now write `tests/tests.nim` synthetic parser isolation tests, and small
`aggregate.nim` action-only JSONL summary CLI. Use native file tools;
supervisor runs Nim commands and gives you errors to review. Do not use
commands or any non-Nim code. Work only these two new files and a concise
worker_report.md inside replays_tools. Never modify reconstruct/ or other
worker files. Read replays.nim only as needed for its exported API.

Tests: construct valid NMMO bytes entirely in Nim with two seats and two
agents each. Check tick-major action access, walk/run/inventory groups,
per-agent attack burst accounting (must not join separate agents), empty
0-tick replay, malformed magic/version/header/truncation/action26,
huge-int multiplication guards, malformed player name, and generic log
marker counts. Simple doAssert, documented main proc, no test framework
and no when isMainModule. Label tests synthetic, not hosted score.

Aggregate CLI takes actions.jsonl. For each report's seats, group by
playerName removing ONLY trailing numeric duplicate suffix e.g. ` (2)`.
Keep original names in output to preserve attribution. Sum ticks (ticks *
seat numAgents), all26 action counts and named groups. Output grouped
player names, seat episodes, total ticks, each group count and fraction,
attack bursts and longest attack/movement run, and total hosted deaths
from result.agent_stats indexed for each seat agent. Do not read scores
or emit scoring/significance/KEEP claims. Header deaths are hosted
outcomes; own re-simulation results are never a score source.
Record number of input replays and distinct sim hashes. Reject malformed
input structures, repeated replay path, negative counts. Use a library
specific exception, Nim style and concise proc docs.

Print a compact Markdown table (name, seat episodes, run %, walk %, noop %,
attack %, inventory %, buy+sell %, deaths) plus a JSON detail record or
only JSON with these obvious fields if easier. Prefer simple ~100 lines
over another extensive framework. Counting is observational description,
not candidate efficacy or statistical evidence.

Write files immediately. Final report includes the original prohibited
read-only Python header inspection, supervisor interruption, and that all
final evidence was recreated with compiled Nim tools. No further Python.
