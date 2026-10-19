# Cogriculture global protocol

`/global` is a read-only spectator feed. It accepts no commands (anything sent
is drained and ignored) and carries **public state only** — no player's shed,
seeds, or unit inventories — so a spectator window cannot be used to scout a
live opponent.

A snapshot is sent immediately on connect, then roughly every 200 ms until the
episode ends, with a final snapshot after it does.

```json
{
  "type": "state",
  "turn": 137,
  "max_turns": 720,
  "day": 5,
  "hour": 17,
  "farms": [ { "money": 4312.0, "tiles": [], "farmer": [4, 4], "hands": [],
               "unlocked_quadrants": ["NW"], "hires_today": 6 } ],
  "market": { "inventory": { "WHEAT": 9950 }, "prices": { "WHEAT": 27 } },
  "town": { "unlocked_shops": ["BAKERY"] },
  "player_names": ["player1", "player2"],
  "money": [4312.0, 3980.0],
  "started": true,
  "paused": false,
  "done": false,
  "results": {}
}
```

`results` is empty until the episode ends, then carries the same object written
to the results artifact.

Before players connect, the snapshot degrades to
`{"type": "state", "started": false, "done": true, "turn": 0}` — this is sent
without waiting, so a viewer that attaches early still gets a first message
promptly.

## Related endpoints

| Route | Purpose |
| --- | --- |
| `GET /healthz` | liveness |
| `GET /client/global` | live farm/market viewer, driven by this feed |
| `GET /client/replay` | Kaggle's own visualizer with the loaded episode injected |
| `GET /client/admin` | pause/resume controls |
| `GET /client/player` | player protocol summary |
| `WS /admin` | `{"command": "pause" \| "resume"}`, replies with a snapshot |
| `WS /replay` | serves the loaded replay when `COGAME_LOAD_REPLAY_URI` is set |
