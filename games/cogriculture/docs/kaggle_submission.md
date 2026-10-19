# Taking a bot between Cogriculture and Kaggle

Bots move in both directions with no edits. This is a design property, not a
convenience: the game container runs the upstream simulator, and the observation
sent over the wire is the upstream observation dict untouched, so there is no
translation layer where the two could diverge.

## The contract

```python
def agent(obs, config):
    return {"farmer": [...], "hands": [...], "market": [...]}
```

- `obs` — the Kaggriculture observation dict (see [RULES.md](RULES.md)).
- `config` — the resolved episode configuration. Optional; a one-argument
  `agent(obs)` works in both places too.
- Returns the action dict described in [player_protocol.md](player_protocol.md).

Two rules keep a bot portable:

1. **One self-contained file, standard library only.** Kaggle submissions are a
   single file. `bots/baseline.py` mirrors the handful of rulebook constants it
   reasons about rather than importing them for exactly this reason.
2. **Stay a pure function of the observation.** Kaggle may run your agent in a
   fresh process, and the Coworld adapter makes no promise about state either.
   Anything you need to know, read from `obs`.

## Cogriculture to Kaggle

```python
# in a Kaggle notebook
from kaggle_environments import make

env = make("kaggriculture", configuration={"episodeSteps": 720})
env.run(["/kaggle/working/baseline.py", "starter"])
env.render(mode="ipython", width=800, height=800)
```

Or submit the file directly to the competition. Check it first against the same
simulator Kaggle runs:

```bash
python tools/eval.py path/to/mybot.py starter --episodes 5
```

## Kaggle to Cogriculture

Drop the file into `bots/` and point the adapter at it:

```bash
python -m cogriculture.player --bot bots/mybot.py
```

Locally, against the real protocol:

```bash
python tools/run_local_episode.py --bots bots/mybot.py bots/baseline.py
```

## Submitting to a Softmax league

The player image already contains the adapter; a policy is the image plus the
bot to run.

```bash
coworld upload-policy <cogriculture-image> \
  --name my-cogriculture-bot \
  --run python --run -m --run cogriculture.player \
  --run --bot --run bots/mybot.py
```

For a bot that is not in the image, bake it into a thin layer on top:

```dockerfile
FROM <cogriculture-image>
COPY mybot.py /app/bots/mybot.py
```

## Where the two differ

Only in transport and in what gets recorded — never in the rules.

| | Kaggle | Cogriculture |
| --- | --- | --- |
| Agent invocation | in-process call | websocket round trip |
| Timeout handling | `DeadlineExceeded` substituted | identical — the same sentinel |
| Reward | final money | `results.scores`, `money` by default |
| Replay | `env.toJSON()` | `env.toJSON()` — the same bytes |
| Opponents | competition submissions | league policies |

The timeout row matters most in practice: a bot that is comfortably fast in a
notebook is also fast over a local websocket, but `actTimeout` is enforced the
same way in both, so an agent that occasionally spikes past a second will drop
turns in either place.
