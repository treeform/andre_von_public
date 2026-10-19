# XP activation adapter

Library `activations.nim` and CLI `activate.nim` turn a statistics plan plus
local hosted log/replay evidence into the activation JSON consumed by the
paired comparison tool. They do not read scores and do not claim KEEP or
significance.

## CLI

```
nim r games/nmmo/buyan/replays_tools/activate.nim <plan.json> <evidence.json>
```

Plan fields copied into the output: `source`, `experiment`, `coworld_id`,
`coworld_version`, `candidate.policy_version_id`. Evidence must have
`source` `softmax-hosted-xp` and `episodes[]` with `xp_id`, `episode_id`,
`candidate_position`, `log_path`, `replay_path`. Relative evidence paths
resolve against the evidence file directory. XP ids must belong to the
plan. Duplicate episode ids, empty paths, and invalid types fail with
`NmmoActivationError`.

## Log text

Hosted coworld CLI downloads may wrap the entire log in one Python
bytes-repr (`b'...'` or `b"..."`). Before splitting lines, the adapter
strictly decodes that optional wrapper in Nim: `\\`, `\'`, `\"`, `\n`,
`\r`, `\t`, and `\xHH`. Unknown or malformed escapes, a missing close
quote, and non-whitespace after the close quote fail. Plain real-newline
text is unchanged. Python is never executed.

## Adapters

Supported experiments: `clean`, `hunt`, `escape`, `sword`, `armor`.

Plain status lines such as `buyan: connected` and
`buyan: episode done, result ...` are ignored. Malformed JSON is fatal.
Result and confirmation events are not counted.

- clean: exact prefix `buyan-clean ` then JSON
  `experiment=clean` `event=activation` with integer `tick`, `agent`,
  `action`, `baselineAction`; `verifiedClean=true`, `clearedCells>0`,
  `extraHints>=0`, `counterfactual=trust-only`; `action != baselineAction`.
  Only individually replay-verified markers count. `trigger_count` is a
  verified lower bound, not all clean changes; summary counters are not
  added without replay tick proof. This is a trust-only counterfactual on
  the same clean observation, not a full baseline run.
- hunt: JSON `experiment=hunt` `event=issued` with `changed` equal to
  `action != baselineAction` and `kind` `walk` or `stage`. Only changed
  events count.
- escape: JSON `event=escape_issue` with integer `tick`, `agent`,
  `action`, `baselineAction`. Any action in 0..25 is accepted. Only
  different actions count.
- sword: JSON `strategy=sword` `event=strategy_action` with integer
  `tick`, `agent`, `generation`, `step`, `candidateAction`,
  `baselineAction`. Count only `candidateAction != baselineAction`. Match
  `candidateAction` to the replay. No `experiment` field is required.
  `held_issued`, `held_confirmed`, `held_failed`, `attack_issued`, and
  `attack_feedback` do not count. Counterfactual is unchanged action
  choice on a copied current Mind, not a separate baseline trajectory.
- armor: space-delimited text after `armor_upgrade `, for example
  `armor_upgrade event=issued tick=100 agent=0 life=0 action=8 slot=helm oldTier=1 desiredTier=3 freshTier=1 issued=1 confirmed=0 tierGain=0`.
  Require `event=issued`, `tick>=0`, `agent>=0`, `action` in 8..16, `slot`
  helm/chest/legs, `oldTier>=1`, `desiredTier>oldTier`, `freshTier=oldTier`.
  No `baselineAction` is invented. Divergence is the source invariant that
  this issued key unequips currently worn armor, while unchanged baseline
  `equipAction` never emits an already-equipped armor key. `confirmed` and
  `summary` lines do not count. Malformed issued lines fail.

Every candidate marker must have `tick` in the replay, local `agent` in
`0 ..< heroesPerSeat`, and the replay action at
`(tick, candidate_position * heroesPerSeat + agent)` equal to the marker
action (`action` or sword `candidateAction`). JSON adapters also require
that action and `baselineAction` in 0..25. Mismatch is fatal. Duplicate
countable `(tick, agent)` markers are fatal. Zero differences yield
`verified=false` and `trigger_count=0`. An issued changed action does not
imply combat, item, or movement success.

## Output

```
{
  "source": "...",
  "experiment": "...",
  "coworld_id": "...",
  "coworld_version": "...",
  "candidate_policy_version_id": "...",
  "episodes": [
    {
      "xp_id": "...",
      "episode_id": "...",
      "candidate_position": 0,
      "verified": true,
      "trigger_count": 1,
      "log_path": "...",
      "metric": "...",
      "replay_path": "..."
    }
  ]
}
```

`metric` names the adapter and the replay action match, plus the clean
lower-bound/counterfactual limit, the sword copied-Mind counterfactual,
or the armor `equipAction` invariant. It does not claim strategy success.

## Tests

`tests/activations.nim` uses synthetic fixtures only. Replay bytes are
generated in Nim. They are not hosted XP scores.

## Supervisor commands

```
nim check --hints:off games/nmmo/buyan/replays_tools/activations.nim
nim check --hints:off games/nmmo/buyan/replays_tools/activate.nim
nim r --hints:off games/nmmo/buyan/replays_tools/tests/activations.nim
```

Do not treat a passing synthetic suite as hosted activation evidence.
