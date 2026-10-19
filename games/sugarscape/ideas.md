# Sugarscape — Masha

Policy: **Masha** (`masha`) — the girl who loves sweets.

Coworld: `cow_62dc18e9-5cf7-438b-8e05-5cb7c8a580bf` (coworld name `sugarscape`)

Grow a target social distribution by submitting one declarative SugarLang ruleset.

## Leagues

- `league_dac00450-027a-45e6-9f6b-c9bda7ddd61d` — Sugarscape Commonwealth
- `league_d5b48dfe-5e08-499f-80f1-63f14720c50c` — Sugarscape Duos
- `league_620a74a7-eb1f-4386-b386-0e7246be4eb6` — Sugarscape Solo

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `baseline` — Target-aware baseline: A readable canned SugarLang policy selected from the assigned target. (run: `python -m players.baseline.player`)

## Baseline

The only bundled example is `baseline` (`players/baseline/player.py`), a
target-aware canned-ruleset picker. **Masha** (`masha/`) is a faithful Nim
port: receive the single `observation` (protocol `sugarscape-v3/1`), switch
on the assigned target's `id`/`variable`, submit ONE SugarLang ruleset, and
exit 0 on a valid ack (the submission window closes early once every seat
has submitted). Canned picks: `wellness.max` → peace + trade + lending +
fertility, pure welfare chase; `wealth.egalitarian` → welfare minus
0.5·preyWealth; population/age_at_death → fertility on, aggression off;
`majority_tribe_share` → welfare ± occupied (converge herds, diversity
spreads); `sick_fraction` → welfare + occupied (endemic) or −2·occupied
(eradicate); `mean_trade_price` → trade on; anything else (including
`wealth.skewed-gini-0.5`) → bare welfare chaser. One extra robustness step
over the Python: an invalid ack falls back once to the minimal welfare
ruleset instead of crashing the seat. Command player — no secret-envs.

Protocol source: coworld-sugarscape docs/PROTOCOL.md, RULES.md, TARGETS.md,
sugarlang-tutorial.md + players/baseline/player.py (fetched via gh api;
blob stubs 404 anonymously).

## Health check (worker)

Symptom: rating 0.3–0.5 in Sugarscape Solo, Duos, *and* Commonwealth — the
dead-seat floor. A working Commonwealth constitution rates ~650–1000+;
Solo/Duos episode scores for a submitting seat are in (0, 1], not a
constant ~0.4.

Root cause: `games/sugarscape/masha/masha.nim:59` (was
`let client = newCoworldClient("masha")`). That dials the game websocket
once with no retry. Hosted player pods often start before the game
socket accepts; the exception killed the seat before it could submit, so
the window closed on the null ruleset (`submitted:false`). Same failure
mode paintbot/morevna hit at its one-shot `newWebSocket`.

Secondary holes on the same path:

- Observation parse (`masha.nim:66`, `message{"target"}`) did not unwrap
  a nested `observation` object and the target switch keyed only on
  `id`/`variable`, not `kind == "maximize"` — the documented branch for
  serving Solo/Duos (distribution) and Commonwealth (maximize) from one
  player. A kind-only maximize observation would skip the constitution.
- `quit(0)` on the first valid ack (masha.nim:75). The game protocol
  allows it, but the platform player contract is "exit when the episode
  ends"; we now wait for `result`.

Wire format (protocol `sugarscape-v3/1`) and SugarLang grammar of the
canned rulesets were already correct: Solo/Duos/Commonwealth variants all
send the same observation *shape* (`target` on the observation object;
Commonwealth's target is a maximize scalar, Solo/Duos a distribution).
Duos does **not** require identical rulesets (independent scores on
distinct global targets). Commonwealth qualifier rounds *do*
(`result.rulesets_identical`); the constitution path is byte-stable (no
randomness) so two self-play seats hash the same.

Fix: retry the websocket dial until connected; parse target from the
observation payload including a nested wrapper and `kind`; stay up
through `result`; share parse/decide with
`games/sugarscape/tools/harness.nim`. Harness feeds PROTOCOL.md
synthetic observations for Solo, both Duos seats, Commonwealth, a nested
wrapper, and a kind-only maximize target; every emitted ruleset passes
the RULES.md grammar check and the two Commonwealth seats match.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Cover `wealth.skewed-gini-0.5` explicitly: the baseline leaves the most
  interesting distribution target on the default welfare chaser; a
  `+0.5·preyWealth` mirror of the egalitarian rule (rich-get-richer
  movement) plus lending should grow the fat tail the target wants.
- Guarded survival rule everywhere (tutorial step 2): `if agent.ttl < 3 →
  pure welfare`, else welfare − 0.4·distance − 2·pollution; the survival
  rule (score 0 unless the scope population is alive at the final tick)
  makes starvation-proofing worth more than target shape.
- `price.equilibrium` tuning: baseline just sets trade:1; add movement
  shaping toward occupied cells so traders actually meet (mean_trade_price
  is zero on ticks with no trades).
- Commonwealth determinism: the qualifier gates `result.rulesets_identical`
  — verify our ruleset is byte-canonical across seats (it is: same code
  path, no randomness), then tune the wellness composite (health, social,
  family components) with fertility/lending toggles.
- Population oscillation damping for `population.carrying-capacity`:
  fertility 1 overshoots and crashes; try a mid fertility with
  occupied-avoidance so growback keeps pace (see the reference
  reproduction_oscillation_* configs).
- Local scenario probes: run the vendored engine (tools/probe_commonwealth
  .py, generate_scenario_pool.py) offline to pre-score candidate rulesets
  per target before spending league rounds. Local sims for TUNING only;
  scoring judgments stay on hosted XP requests.
- Duos ladder: in 2-seat episodes both seats' agents share the world —
  aggression 0 is cooperative but exploitable; test whether a mild
  aggression against the rival seat's agents moves our own target match.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
