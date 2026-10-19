# Derks Gym — Bogatyr

Policy: **Bogatyr** (`bogatyr`) — the strongman in the gym.

Coworld: `cow_03c45b25-de4b-42e1-8e2f-056a496878c4` (coworld name `derks-gym`)

Derk's Gym: PufferLib's Ocean MOBA with a pre-match loadout draft. Six seats, three per team, one hero each (the other four heroes are driven in-process by the vendored pretrained network); before tick 0 all six seats simultaneously and blindly pick one ARM, one TAIL and one MISC item from a 12-item catalog, and the summed, clamped stat deltas are written into the heroes for the whole match. Then it is the upstream 5v5 MOBA, bit-exact with the training environment: the same C sim compiled to wasm, the same 510-byte observations and [7,7,3,2,2,2] MultiDiscrete actions, creep waves down three lanes, 24 towers and two 4500-HP Ancients. The match is won by destroying the enemy Ancient, or at the tick cap by remaining Ancient health. The policy is metagame plus micro: the draft is one decision that shapes 6000 ticks. Replays re-simulate deterministically in a static wasm viewer from the recorded seed, loadouts and per-tick action log.

## Leagues

- `league_44e55a9f-aa40-4523-9ed0-7f86ccc73d08` — Derks Gym

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `baseline` — baseline: puffer-forge: a deterministic draft rule (one fixed item set per role) plus the upstream PufferLib pretrained policy (moba_weights.bin through the vendored puffernet compiled to wasm) for the per-tick micro. The certification fixture player and the image's default. (run: `python -m players.derk_player`)
- `lane-brawler` — lane-brawler: lane-brawler: a draft rule derived from the observed base stats plus the hand-coded finite-state lane-push bot for the micro (no pretrained weights). (run: `python -m players.derk_player`)
- `drafter` — drafter: derk-drafter-v1: one Anthropic call decides the loadout before tick 0, then the vendored pretrained network plays every tick. With no API key it falls back to the puffer-forge draft rule and still plays a legal, complete episode. (run: `python -m players.derk_player`)

## Baseline

Three bundled examples: `baseline` (puffer-forge: fixed per-role draft +
the vendored pretrained puffernet for micro — the image default and
certification fixture), `lane-brawler` (stats-derived draft + the
hand-coded FSM lane-push bot, no weights), and `drafter` (one Anthropic
call for the draft, pretrained micro; falls back to puffer-forge without
credentials). Our policy **Bogatyr** (`bogatyr/bogatyr.nim`) is a
command player: a Nim port of `lane-brawler`, differentially tested
against the Python reference (1800 ticks across 30 synthetic episodes,
bit-identical actions; harness under `-d:bogatyrTest`). Draft: cleaver/
plate/focus on tanky stats, needler/rotor/regen otherwise, straight from
the observed base stats. Micro: BFS cost-field steering over the
embedded 128x128 wall grid (sha256 ec17403c... verified), lane waypoints
to the enemy Ancient, siege standoff at tower range +1 until a friendly
creep engages, retreat-to-fountain at <=3/10 health with exit at 8/10,
90-degree stuck detours, per-role skill flags, target filter 0 with
creeps visible else 2. Zero model calls — upload needs NO secret-envs
(only PLAYER_PROMPT drafters need USE_BEDROCK for the sidecar).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Draft vs the field, not the mirror: lane-brawler's rule keys only on
  own stats. Wire role-aware counter-drafting from the draft
  observation's opponent roles (e.g. tail_plate into double-burst
  opposition, tail_stinger into supports) — the draft doc says
  counter-drafting is the metagame.
- Group with the creep wave: the reference pushes waypoints regardless
  of wave position; hold at the frontmost friendly creep cell when
  ahead of the wave (tower dives aside, lane trades favour the side
  with creeps soaking).
- Focus fire on hero_d: when an enemy hero is at distance <= 2 and our
  health10 - 3 exceeds a guess of theirs, keep target filter 2 to bias
  basic attacks onto the hero instead of the wave.
- Late-game grouping: after any tier-4 tower dies (dead-tower memory
  already tracks it), collapse all three seats' lanes onto the mid
  waypoint line for the Ancient race instead of split-pushing.
- Retreat pathing through safe lanes: retreat currently BFS-beelines to
  the fountain, which can cut through the enemy jungle; bias the cost
  field with a penalty band around live enemy towers.
- Port puffer-forge's draft table as an env-switch (BOGATYR_DRAFT=forge)
  to A/B the two draft rules with identical micro in the same league.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| - | fleet/triage candidate v2 | see git history | triage batch | paired vs champion | REVERT: 0.55->0.45 t=-1.0 0/10 |
| 1 | Group with the creep wave | In PUSH, when friendly creeps are visible and we are strictly closer to the current goal than the frontmost one, hold instead of walking past the wave. Siege standoff, tower-flee, and engage-dives are unchanged (surfable=false). Draft unchanged. Aimed at the 58–58 draws vs derk-drafter-v1 / derks-gym-example: those are puffernet micro and do not lead the wave; our waypoint follower does, so we soak shots creeps should take and lose the Ancient-health tiebreak. | | | |
