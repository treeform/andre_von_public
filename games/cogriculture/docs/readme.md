# Cogriculture

A Coworld cogame of Kaggle's [Kaggriculture](https://www.kaggle.com/competitions/kaggriculture):
two farmers work adjacent 10×10 farms for a 30-day season, growing crops,
raising livestock, hiring help, and trading into a market whose prices move with
what everyone sells. Most money in the bank at the end wins.

**The simulation is not a clone — it is the upstream simulator.** Cogriculture
vendors `kaggriculture.py` from a pinned `kaggle-environments` release and runs
it unmodified. There is no reimplementation to drift, no rule transcribed twice.
See [`vendor/UPSTREAM.md`](vendor/UPSTREAM.md).

**Bots are portable in both directions.** A Cogriculture bot is a plain Kaggle
agent — `agent(obs, config) -> action_dict` — and the observation it receives
over the wire is byte-for-byte the observation Kaggle would hand it. The same
file submits to Kaggle and competes in a Softmax league.
See [`docs/KAGGLE_SUBMISSION.md`](docs/KAGGLE_SUBMISSION.md).

The authoritative ruleset is [`docs/RULES.md`](docs/RULES.md) (upstream's own
README, vendored alongside the code it documents).

## Rules at a glance

- **2 players, 720 turns** — 24 turns a day for 30 days. One action per unit per
  turn; up to 10 market orders per turn.
- **Grow things.** Wheat, carrot, tomato, strawberry and melon differ in seed
  cost, time to yield, and whether they yield once or keep producing. Every
  plant must be watered daily — miss two days running and the tile becomes a
  weed. A tile planted today is *already* one day from that, so plant and water
  in the same day.
- **Or raise animals.** Geese, cows and sheep need a coop or pasture, daily wheat
  feed, and produce eggs, milk and wool. Miss two feeds and they escape for good.
- **Hire help.** A farm hand costs `fib(n)` for the n-th hire that day — 1, 1, 2,
  3, 5, 8 — and gives you a whole extra unit's worth of actions until nightfall.
- **Sell into a live market.** Every product's price moves with market
  inventory: it climbs as the town's shops consume stock and falls as players
  sell. Each product has its own curve, and the premium ones (strawberry, melon,
  milk, wool) collapse to the $1 floor on a modest glut.
- **Buy land.** Each farm starts on one 5×5 quadrant; the other three cost
  $1,000, $2,000 and $4,000.

## Quick start

Run an episode in-process — fastest loop for bot work:

```bash
python tools/eval.py bots/baseline.py bots/starter.py --episodes 3 --diagnose
```

Run one over the real websocket protocol, exactly as a Coworld episode does:

```bash
python tools/run_local_episode.py --steps 720 --serve
```

That prints a live view at `/client/global` and, with `--serve`, a replay at
`/client/replay` rendered by Kaggle's own visualizer.

Run the tests:

```bash
python -m pytest tests/ -q
```

## Writing a bot

A bot is one self-contained file with a module-level `agent` function:

```python
def agent(obs, config):
    farm = obs["farms"][obs["player"]]
    return {"farmer": ["WATER"], "hands": [], "market": [["SELL", "CARROT", 3]]}
```

Point the player adapter at it:

```bash
python -m cogriculture.player --bot path/to/mybot.py
```

Two are bundled:

| Bot | What it is |
| --- | --- |
| [`bots/starter.py`](bots/starter.py) | Upstream's `starter_agent` — a one-tile carrot loop. Weak on purpose; a fixed reference point. |
| [`bots/baseline.py`](bots/baseline.py) | The shipped baseline: zoned unit assignment, staged crop portfolio, rate-limited selling. Scores ~6× starter. |

`bots/baseline.py` opens with the reasoning behind its strategy — worth reading
before writing your own, if only to disagree with it.

## Layout

```
vendor/kaggle_environments/  the upstream simulator, byte-for-byte (see UPSTREAM.md)
cogriculture/sim.py          the one place that decides which simulator we run
cogriculture/server.py       Coworld game runnable: websockets around env.step()
cogriculture/player.py       Coworld player runnable: websockets around a Kaggle agent
cogriculture/client/         live viewer, admin, player docs
bots/                        plain Kaggle agents, portable to Kaggle unchanged
tests/                       vendor identity + upstream parity
tools/                       vendoring, golden recording, eval, local episodes
```

## How identity is enforced

Three layers, because "we run upstream" is a claim that has to stay true:

1. **Vendored bytes.** Everything under `vendor/kaggle_environments/` is
   upstream's, with one 40-line `__init__.py` of ours that registers a single
   environment instead of all 24 (upstream's version drags in jax, open_spiel and
   transformers, which kaggriculture does not use).
2. **`tests/test_vendor_identity.py`** downloads the pinned wheel and asserts
   every vendored file matches it byte-for-byte, that our `__init__.py` is the
   *only* deviation, and that it contains no game logic.
3. **`tests/test_parity.py`** replays six scenarios — including a full 720-turn
   season — against goldens recorded from a real installed
   `kaggle-environments`, comparing a full-state hash at every step.

Upstream bumps are a re-vendor plus a golden re-record, never a port:

```bash
python tools/vendor_upstream.py --version <new-version>
python tools/record_parity_goldens.py
python -m pytest tests/ -q
```

## Known characteristics

- **Replays are gzipped episode JSON** — the artifact is `env.toJSON()`, the
  Kaggle episode format (which re-states every agent's full observation at
  every step, ~12 MB raw for a full season), stored gzip-compressed at
  ~180 KB, with the platform-supplied player names recorded as
  `info.TeamNames` so the visualizer can label players. `gunzip` of the
  artifact is byte-for-byte a real kaggriculture episode; readers sniff the
  gzip magic, so pre-compression replays (plain JSON) still load. See
  `cogriculture/artifacts.py`.
- **Replays play in a static viewer, not a game container.** The manifest
  declares `game.replay_viewer.bundle`, so Observatory watches a replay by
  opening a static bundle — upstream's own visualizer split into an
  immutable-cacheable `app.js` (~0.6 MB of code, with the inlined 1024px
  sprite PNGs extracted to content-addressed `sprites/*.webp`, ~90% smaller
  and fetched in parallel) plus a small loader `index.html` — with the
  replay URL in `?replay=`. No Kubernetes job, no image pull, no proxied
  ~26 MB page. `tools/build_replay_viewer.sh` builds the bundle
  (`make replay-viewer` locally); the game image's `/client/replay` remains
  as the local-dev and fallback path.
- **Episodes are fast** — a full 720-turn season with rule-based bots runs in
  about 4 seconds wall-clock. `actTimeout` (default 1 s, matching Kaggle) is the
  ceiling that matters for slower or LLM-backed players: 720 turns × 1 s is
  ~12 minutes worst case.
- **Score scale is unbounded.** `scoreMode` defaults to `money` — literally the
  Kaggle reward — and can be set to `winloss` for ±1 scoring if a ladder's
  mean-score ranking proves noisy against a strategy-dependent money scale.
