# Hive - spectator channel (hive.global.v1)

`WS /global` streams one JSON snapshot per turn and one on every connection:

```json
{"type": "state", "game": "hive", "protocol": "hive.global.v1",
 "t": 1680, "turn": 7, "ticks": 4800, "turns": 20, "fps": 24,
 "speeds": [1,2,3,4,8,16],
 "field": {"cols": 160, "rows": 88, "cell_px": 8, "blocks": [20,11],
           "block_cells": 8, "rock": [ ... 11 rows of 20 chars ... ]},
 "colonies": [{"seat": 0, "nest": 0, "alias": "Amber", "colour": "#f2c14e",
               "cell": [16,12], "player": "daveey", "delivered": 118,
               "carrying": 6, "scouts": 4, "doctrine": { ... },
               "doctrine_source": "llm"}, ... 4 ... ],
 "ants": [[cx, cy, state, colony], ... 96 ... ],
 "sources": [{"id": 12, "cell": [76,43], "amount": 41, "spawn_amount": 60}],
 "scoreboard": [{"colony": "Amber", "delivered": 118}, ... ],
 "started": true, "done": false, "connected": [true,true,true,true],
 "events": [ ...the last 40 events... ]}
```

Ant state codes: 0 searching forager, 1 searching scout, 2 carrying, 3 held by recall.

Real player names appear only in `colonies[].player`, and only when `showPlayerLabels` is set; every in-game surface sees the colony alias.

`GET /client/global` is a real browser page over the same feed. `GET /client/player` is the seat's documentation page and deliberately never opens the player websocket. `/healthz` and `/global` keep answering for a 20 s shutdown grace after the artifacts are written.

Replays are a STATIC wasm bundle, never a pod: the viewer re-runs the same integer sim from the recorded doctrine stream in the browser and verifies its own re-derivation against the u32 digest in every keyframe. It contacts nothing but the S3 URL it was given.
