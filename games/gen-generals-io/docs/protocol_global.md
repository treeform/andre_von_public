## The spectator socket

`/global` speaks the Sprite v1 binary protocol: sprite definitions, object
placements, a viewport and a layer, exactly as `client/broadcast_core.js`
decodes them. The broadcast chrome rides as the LABEL of the reserved 1 × 1
sprite id 4090, which is what makes it survive a hosted replay.

One chrome object per presentation frame. The inherited keys (`t`, `mt`,
`ph`, `lob`, `sp`, `mx`, `st`, `lp`, `sk`, `ff`, `en`, `mm`, `teams`,
`roster`, `events`, `lead`, `lulls`, `beats`, `over`) are the starter's;
gen-generals-io adds:

```json
{"turn": 96, "turns": 240, "growthIn": 4, "growthEvery": 25,
 "w": 16, "h": 10,
 "cells": [{"i": 37, "k": "plain", "o": 0, "a": 54}],
 "gen":   [17, 28, -1, 142],
 "alive": [true, true, false, true],
 "stand": {"land": [31,27,0,34], "army": [210,188,0,156], "cities": [1,2,0,0]},
 "out":   [-1, -1, 71, -1],
 "outBy": [-1, -1, 1, -1],
 "plan":  [{"seat": 0, "turn": 96, "intent": "expand", "source": "llm",
            "note": "taking the middle before blue does"}]}
```

`cells` is a **delta** (the full array on the first frame and on every
keyframe); `i` is a cell index and `o` a seat index or `-1` for neutral.
`gen[s]` is seat `s`'s crown cell, or `-1` once captured. **The per-seat fog
is NOT transmitted**: the viewer derives `visible[s] = owned ∪
8-neighbours(owned)` in the browser exactly as the sim does, which costs zero
replay bytes and cannot drift.

## Derived events — a closed enum of twelve kinds

`phase`, `growth`, `claim`, `citytaken`, `tilelost`, `stackclash`,
`generalspotted`, `generalcaptured`, `eliminated`, `plan`, `fallback`, `end`.

**Beats** — the scrubber markers, and the only kinds the game block draws:
`citytaken`, `generalspotted`, `generalcaptured`, `end`. Each is a labelled,
clickable button that seeks on click.

## The replay

Binary, magic `COWLDGEN`:

```
"COWLDGEN" | u16 formatVersion | u16 len + game name | u16 len + game version
           | u32 len + the resolved config JSON
           | records: u8 kind, u32 length, payload
```

Record kinds: `1` join, `2` **plan input** (load-bearing, re-applied before
the turn it belongs to is stepped), `3` chat (`register` / `plan` /
`fallback` / `budget_guard` / `stop` / `result`), `4` hash (u32 turn, u32
`gameHash`), `5` leave.

The board is **re-derived from the seed** rather than stored — it is in
`gameHash` from turn 0, so a divergence surfaces immediately. Everything the
viewer needs is in the bytes; no server is contacted except S3 for the file.
`tools/replay_summary.py` (Python 3 stdlib only) prints one strict-UTF-8 JSON
object describing a replay.
