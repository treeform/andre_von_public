# Cogriculture player protocol

A player connects to the game's `/player` websocket with its assigned `slot` and
`token` query parameters, both already encoded into `COWORLD_PLAYER_WS_URL`.

The defining property of this protocol: **the `observation` field is the
upstream Kaggriculture observation dict, unmodified**, and the `action` field is
the upstream action dict. Nothing is remapped. A bot written for Cogriculture is
a Kaggle agent, and a Kaggle agent is a Cogriculture bot.

## Messages

### `handshake` — game to player, once on connect

```json
{
  "type": "handshake",
  "slot": 0,
  "player": 0,
  "configuration": { "episodeSteps": 720, "turnsPerDay": 24, "boardSize": 10, "...": "..." },
  "player_names": ["player1", "player2"],
  "upstream_version": "1.32.2"
}
```

`configuration` is the resolved episode configuration, the same object a Kaggle
agent receives as its second argument. `upstream_version` names the pinned
`kaggle-environments` release the simulator came from.

### `observation` — game to player, once per turn

```json
{
  "type": "observation",
  "slot": 0,
  "turn": 137,
  "observation": { "player": 0, "day": 5, "hour": 17, "farms": [], "market": {}, "town": {}, "private": {} }
}
```

The `observation` object is documented in full in [RULES.md](RULES.md) under
"Observation Format". Both farms are public; `private` (shed, seeds, per-unit
inventories) is yours alone — the opponent's private state is never sent.

### action — player to game, once per observation

```json
{
  "action": {
    "farmer": ["WATER"],
    "hands": [["PLANT", "MELON"], ["HARVEST"]],
    "market": [["SELL", "CARROT", 3], ["BUY_SEED", "WHEAT", 5]]
  }
}
```

A bare action dict without the `action` wrapper is also accepted.

- `farmer` — one action for the main farmer.
- `hands` — one action per hired hand, in the order they appear in
  `farms[you].hands`. Extra entries are ignored.
- `market` — an ordered list; only the first `maxMarketOrdersPerTurn` (default
  10) are processed and the rest are **dropped silently**. A full `HIRE` batch
  alone can fill the quota, so spread hiring, buying and selling across turns.

Every action verb, its arguments, and its legality conditions are in
[RULES.md](RULES.md).

### `final` — game to player, once at episode end

```json
{ "type": "final", "done": true, "slot": 0 }
```

The player should exit cleanly on receipt.

## Timing

A slot has `actTimeout` seconds (default 1, matching Kaggle) to answer each
observation. A slot that is slow, silent, or disconnected has `DeadlineExceeded`
substituted for its action — the same object Kaggle's own runner substitutes —
and the turn is recorded with status `TIMEOUT`. The episode continues.

Replies that arrive after their turn resolved are discarded rather than applied
to the next turn, so a slow bot never banks an extra action.

## Minimal player

```python
import asyncio, json, os, websockets

async def main():
    async with websockets.connect(os.environ["COWORLD_PLAYER_WS_URL"]) as ws:
        config = {}
        async for raw in ws:
            message = json.loads(raw)
            if message["type"] == "handshake":
                config = message["configuration"]
            elif message["type"] == "final":
                return
            elif message["type"] == "observation":
                action = my_agent(message["observation"], config)
                await ws.send(json.dumps({"action": action}))

asyncio.run(main())
```

In practice you do not write this: point the bundled adapter at any Kaggle agent
file instead.

```bash
python -m cogriculture.player --bot bots/baseline.py
```
