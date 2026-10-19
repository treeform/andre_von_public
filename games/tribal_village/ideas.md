# Tribal Village — Yarilo

Policy: **Yarilo** (`yarilo`) — god of spring and village life.

Coworld: `cow_6e77a73f-dd53-4371-b598-4965c0ffb12b` (coworld name `tribal_village`)

A 2-8 team Tribal Village Coworld with six agents per village. One entrant policy controls all six teammates while they gather, craft, fight tumors, and defend their territory.

## Leagues

- `league_aedc4933-a75a-40ab-aaef-1653e0796875` — Tribal Village

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `villager` — Villager Scripted AI: Bundled native Nim player that mirrors the episode deterministically and replays the built-in role-based scripted AI through the Coworld player WebSocket. (run: `/bin/villager`)

## Local baseline

~/p/tribal-village — local repo.

## Baseline

- Default and strongest example: `villager` (the only bundled player). It is a
  deterministic mirror: observations carry NO world state (just slot, tick,
  seed), so it rebuilds the whole episode locally from `game_config.seed` and
  replays the game's built-in role-based scripted AI (src/ai.nim) for its slot.
- Our policy `yarilo` is a faithful port of that mirror: upstream
  players/villager/villager.nim adapted, with the game sources (environment,
  ai, terrain, objects, rng_compat, equipment) vendored verbatim from
  coworld-tribal-village @ 7a5f6a21 into `yarilo/src/`, plus a trimmed
  headless `common.nim` (upstream's mixes in boxy/windy desktop UI globals;
  only the game constants are kept, byte-identical in behavior).
- The mirror MUST match the server's engine version exactly — when the
  coworld package version bumps, re-vendor from the manifest's pinned
  source_url commit or the mirror desyncs and plays garbage.
- Deviating from built-in AI for our own six slots keeps OUR mirror correct
  (the server applies what each seat sends) but desyncs every opponent
  villager mirror's prediction of us — and any opponent deviation desyncs us.
  Deviations are only sound if the mirror ingests nothing about other agents,
  which it does; treat any deviation experiment as high-risk.
- Upload: no secret-envs needed (fully scripted, no LLM seat).

## Version check (worker)

Checked 2026-09-01. Hosted coworld `cow_6e77a73f-dd53-4371-b598-4965c0ffb12b`
is still `tribal_village` **0.1.30**, canonical, created 2026-08-10. Manifest
`game.version` is `0.1.30`; runnable / villager / commissioner `source_url`
still pin `coworld-tribal-village` @ `7a5f6a215a49d8625dce5e4d552fb290e0b390bb`
(the scaffold pin). Vendored `yarilo/src/{ai,environment,terrain,objects,rng_compat,equipment}.nim`
are byte-identical to that commit. `common.nim` remains the intended headless
trim (66 lines vs upstream 161; UI/boxy/windy half dropped). GitHub HEAD is
one commit ahead (`96514968`, "Update canonical Village release status") and
touches only README.md — no engine files, no new modules.

**Action taken: none.** Version did not bump; no re-vendor.

Low league rating (55, rank #3 of 6 as of this check) is not a version-desync.
Dash `tribal-village` (league_aedc4933, 2026-09-01): six competing champions.

| rank | player | policy | rating | mean score | rounds (this field) |
|------|--------|--------|--------|------------|---------------------|
| 1 | Andrew Brower | tribal-village-example:v1 | 102 | 121 | 2 |
| 2 | relh | relh-tribal-village-starter:v1 | 90 | 88 | 5 (412 career) |
| 3 | Andre von Auto | yarilo:v1 | 56 | 111 | 3 |
| 4 | richard | richard-tribal-village-starter:v1 | 31 | 68 | 5 (412 career) |
| 5 | daveey | tribal-village-warden:v1 | 6 | 60 | 5 |
| 6 | docxology | v5_tribal_village:v1 | -18 | -16 | 5 (412 career) |

Yarilo's three league scores were +198.6 (1st), +92.7 (4th), +42.4 (3rd).
Mean 111 is second-best on the field, next to the bundled-named
`tribal-village-example`. A broken mirror (the "plays garbage" failure)
looks like docxology's `v5_tribal_village` (~−16 every round). Rating 55
is a 3-round TrueSkill cold start against relh/richard's 412-round
histories, not a symptom of a desynced sim.

Opponent deviation (the known fundamental risk) is real on this field:
`tribal-village-warden` and `v5_tribal_village` are not the bundled
villager, so they desync every villager-mirror's prediction of those
villages. Same-round scores still swing ~200 points among the
starter/example/yarilo names, which is also consistent with asymmetric
village maps (identical AI on different villages is not equal score).
No evidence that opponent deviation is currently turning *our* six slots
into garbage actions — do not change the mirror without a replay that
shows our actions diverging from built-in AI on our own seats.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

1. Deviation experiment: keep the mirror for world tracking but override our
   six slots' actions with a tuned controller (e.g. more lantern planting —
   healthy planted lanterns are the durable team reward per rules.md). Verify
   via XP request whether opponent-mirror desync actually hurts us or only
   them.
2. Role rebalance inside the built-in controller: bias more agents into
   lantern-planting/territory roles and fewer into redundant gathering (edit
   the vendored ai.nim role assignment, all six slots consistent).
3. Defense tuning: earlier spear/armor crafting before tumor waves (ai.nim
   crafting thresholds), measured against scripted villages.
4. Anti-tumor focus: prioritize attacking spawner-adjacent tumors when a
   fighter has spear charges, to protect lantern territory income.
5. Give-chain economy: use the `give` verb to concentrate bread/resources on
   frontline agents (built-in AI rarely does); needs a deviation-safe variant
   of idea 1 first.
6. Robustness: on tick-skew or desync suspicion (reward stream diverges from
   mirror prediction), fall back to noop instead of garbage actions to avoid
   feeding opponents free kills.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| - | fleet/triage candidate v2 | see git history | triage batch | paired vs champion | REVERT: 83.5->5.2 t=-5.5 BROKE MIRROR |
| 1 | Lighter plant-now, no push | Score is healthy lantern COUNT (0.02 team/tick), not tint area; `lanternHealthy` is never cleared. Lighters now plant on any legal adjacent tile this tick (prefer spaced tile closest to home) and skip the expand/push wander that used to follow every plant, so wheat→loom resumes immediately. | | | |
