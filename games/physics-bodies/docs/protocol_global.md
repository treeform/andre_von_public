THE RING — the spectator wire contract.

GET /global (and GET /replay) upgrades to a spectator websocket, which refuses
any request carrying player credentials. GET /healthz answers `healthy` and keeps
answering for a bounded ~20 s after the artifacts are written. GET /client/global
and GET /client/player serve the real broadcast page and neither opens the player
socket. GET /replay-data serves the recorded replay bytes.

A spectator receives the same binary Sprite v1 board stream plus the broadcast
chrome frame. The chrome rides the SAME binary channel as the board — as the
LABEL of a reserved never-drawn 1x1 sprite (id 4090) — because that is the only
channel that survives a hosted replay.

The chrome frame's keys are:

  t, mt, ph, lob, pl, sp, mx, st, lp, sk, ff, en, mm, bs, pov, teams, roster,
  events, turn, turns, turnTicks, pb, intents, lead, beats, lulls, over, hold

`teams` has exactly two keys, `bug1` and `bug2`, each carrying the live zero-sum
score, round wins, knockdowns suffered, ring-outs, knockouts, contacts, distance
from the centre, tilt percent, whether the bug is down, grounded legs and
posture. `roster` is spectator-side ONLY and is where the REAL policy names live,
one entry per seat with the bug it drives, its policy kind and its LLM/fallback
turn counts. `pb` carries the ring (centre, live radius, round-start radius,
minimum radius), the round (index, tick, clinch target, the round log), both bugs
with all four feet and their per-foot grounded/load flags, the last contact and
the two scores. `intents` carries the recent order records, which is where a
spectator SEES the LLM playing.

Derived beat events: phase, round_start, contact, shove, stagger, knockdown,
rim_slip, ring_out, round_end, match_point, turn_end, gameover. Only knockdown,
ring_out, round_end, match_point and the terminal verdict become SCRUBBER BEATS;
contact, shove, stagger and rim_slip fire dozens of times a round and would bury
the timeline.

Viewer input rides the same socket as Sprite v1 client messages: a chat message
`s:<tick>` seeks and single characters drive the transport (space, p, P, b, e, r,
f, '.', ',', and the speed keys 1 2 3 4 8 6).

THE REPLAY is binary, magic `COWLDPBD`, format version 1, game name
`physics-bodies`, game version `1`. It carries: the header; the resolved config
JSON (seed, `perm`, the whole match shape, every geometry and actuation constant,
the roster with real names); the joins and leaves; THE ACTION LOG — one command
byte per seat per tick, written on change only; the chat control records
(`register`, `intent`, `fallback`, `budget_guard`, `round`, `stop`, `result`),
each a JSON object told apart by a leading '{'; and ONE gameHash per tick. Only
`stop` is load-bearing at playback — every other fact re-derives from the action
log by re-running the same integer sim, and the hash chain is checked every tick
in the browser.

The replay is served by the STATIC wasm bundle
(`game.replay_viewer.bundle = static-replay-viewer`), never by a pod. The bundle
compiles the SAME `src/bodies/sim.nim` under emscripten and re-simulates every
frame from the recorded bytes.

`tools/replay_summary.py` (Python 3 stdlib only) prints one strict-UTF-8 JSON
object for a `.replay` path: protocol, gameVersion, seed, names, aliases, bodies,
policyKinds, tickCount, rounds, intents, fallbacks and the full results document.
