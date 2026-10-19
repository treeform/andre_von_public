# Territory — Volot

Policy: **Volot** (`volot`) — the land giant.

Coworld: `cow_e7cac219-31d0-45c5-93f8-649434351365` (coworld name `territory`)

Nine LLM Cogs paint their claim onto a hex lattice of resource walls. A claimed wall pays income forever — until someone razes it, and razing is permanent: once to strip the claim and halve the yield for everyone, twice to turn the wall into rubble that can never be claimed again. Strike a Cog's home ring in two consecutive turns and it is eliminated, its whole territory reverting to unclaimed ground. Talk is free, public or private, and binds nobody. The board only ever gets poorer; the score is gross paint earned. The question is whether nine agents can keep it rich.

## Leagues

- `league_dcc3daee-8099-4fd1-b321-da10e1be9a64` — Territory

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `territory-homesteader` — Territory Homesteader: Deterministic no-LLM baseline: claims the richest reachable wall it can afford, never razes. Always legal, so it certifies the contract offline. (run: `/bin/territory-player`)
- `territory-raider` — Territory Raider: Deterministic no-LLM baseline: homesteads, then from turn 4 razes the leader's richest reachable wall. (run: `/bin/territory-player`)

## Baseline

Two example players ship in the game image, both scripted sides of
`/bin/territory-player`: `territory-homesteader` (the default: claim the
richest reachable walls affordable, max 3/turn, never raze) and
`territory-raider` (homesteads, then from turn 4 razes the banked leader's
richest reachable wall with yield >= 3, max 4 claims). The raider is the
more aggressive one but razing is negative-sum for the razer's own gross
score, so homesteader is likely the stronger seat under this scoring.

`volot/volot.nim` is a Nim port of BOTH baselines (verified against
`src/game/scripted.ts` in Metta-AI/cogame-territory @ ad1e8df, including
the tuned params maxClaims 3 / 4 and minYield 3 and the exact sort
comparators), selected by `PLAYER_SCRIPTED=homesteader|raider`, default
homesteader — plus one scoring-math overlay on the homesteader path:
after turn 14 it strip-mines own walls when `4 × effYield` beats remaining
income, and on the last turn it skips claims (they dry too late to pay).
Command player, cogweb.player.v1, replies `{orders, messages: []}` per
observation. Protocol pinned from upstream source — high confidence. No
secret-envs needed on upload (no LLM seat).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Late-game salvage: from turn 14 the docs price salvage (4 x effYield) above
  holding — add an endgame strip-mine pass that razes our own tiles when
  `4*effYield > effYield*(turnsLeft)`, richest first, budget permitting.
- Frontier-blob claiming: bias the claim comparator toward tiles adjacent to
  2+ tiles we already own (option value) instead of pure yield — thin spikes
  give one projection origin, blobs give many.
- Smear avoidance: track tiles other seats publicly said they are taking
  (inbox parsing) and tiles adjacent to rivals' wet frontier; deprioritize
  contested claims to dodge same-turn smears where both pay and nobody holds.
- Distance-1-first budgeting: claiming at distance 1 costs 4 vs 6 — measure
  whether strictly preferring dist-1 (yield tie-break second) beats the
  upstream yield-first comparator on gross income over 18 turns.
- Counter-raze defense: when `lastTurn.struckBy` is nonempty, raze the
  attacker's nearest foothold within 2 of our home ring (the documented
  shield) before any claiming.
- Cheap-talk borders: broadcast which frontier tiles we intend to claim next
  turn (talk is free); LLM opponents may honour the border and smears drop.
- Transfer diplomacy: small transfers to the second-place seat to point the
  raiders' leader-targeting logic at someone else (leader is by `banked`).

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | late-game salvage: after turn 14, 4×effYield beats holding and last-turn claims pay 0 | homesteader: raze own wall tiles in razeReach when 4*y > y*(turns−T), richest then cheaper; leftover order slots after the usual 3 claims, except last turn is salvage-only (max 8). Skip cracked (2nd raze pays 0) and y=0. |  |  |  |
