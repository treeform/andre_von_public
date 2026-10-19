# Jumper — Sivka-Burka

Policy: **Sivka-Burka** (`sivka_burka`) — the leaping magic horse.

Coworld: `cow_73b56196-81e9-4b1d-8f0e-f5393ba203c4` (coworld name `jumper`)

A cooperative BitWorld platformer where players cross pits, stack on each other, and reach the flag.

## Leagues

- `league_f140dae4-e5fd-4d22-b8eb-67bc99e880ba` — Jumper

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `dalli` — dalli: Deterministic flag-seeking baseline Jumper bot. (run: `/bin/dalli`)

## Local baseline

~/p/coworld-jumper — our leapfrog:v3 (4.33 flags), beats the dalli base.

## Baseline

- Platform default/example: `dalli`, the bundled deterministic
  flag-seeking baseline (0.83 flags per game, never won a round).
- Strongest local source: `players/dalli` on the `dalli-wall-climbing`
  branch of ~/p/coworld-jumper (tip ea00455) — the shared-brain
  hardcoded-route bot: 5.92 flags per game and 39 of 40 hosted episodes
  won against the live league lineup. This superseded leapfrog:v3
  (4.33 flags); the old reactive leapfrog is players/leapfrog there.
- Sivka-Burka is a straight port of that bot: `brain.nim` (route +
  elevator wall-climbing logic, forest.tmx map baked in at compile
  time) plus a self-contained sprite-protocol websocket layer in
  `sivka_burka.nim` (bitworld dependency inlined; deps are whisky
  only). Seats join as `sb<random>`; every seat runs the full route
  because the policy is scored by the mean over its seats.
- Command player: no upload secret-envs needed (no LLM seat, no
  USE_BEDROCK).
- Wall-climbing on teammates is the whole game: three walls (tiles
  x23, x38, x57) are taller than the 91 px solo jump, and score tracks
  time-spent-riding-a-teammate almost exactly.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Rival-ladder use: the brain only mounts bodies generically; detect
  non-`sb` rivals parked at a wall pocket and climb them first, saving
  our own seats from ladder duty entirely.
- Apex-jump timing sweep: ApexMargin (14 px) and RidePatience (48
  ticks) were tuned against the old lineup; sweep both against the
  current field in one hosted XP batch.
- Faster return leg: after a flag capture the bot respawns at the
  start; check whether the route replays cleanly from every respawn
  and shave the walk back to wall 1 (takeoff windows allow earlier
  jumps when nobody blocks the pocket).
- Pocket contention: when two of our seats reach a wall together the
  stagger id decides who pins; try yielding by lower remaining
  distance-to-flag instead, so the seat closest to scoring climbs
  first.
- Name-tag hardening: self-identification falls back to
  viewport-center tracking when the tag is occluded; add a short
  motion-signature check (our own last input vs observed velocity) to
  avoid tracking a sibling after respawn pile-ups.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| - | fleet/triage candidate v3 | see git history | triage batch | paired vs champion | REVERT: 5.70->5.60 t=-0.1 5/10 |
| 1 | map memory + hole-veto + no-wait + head-bait (all four at once) | additive on v1 route | xreq_95b69e49 | top-4 field, 12 paired eps | REVERT: v2 5.42 vs v1 5.92 (t=-1.00). Retry ideas ONE at a time — the veto-stop or bait-wait likely eats route time |
| 2 | rival-ladder: yield the pocket to a visible non-sb body instead of pinning first | If a named non-`sb` player is in a wall's approach zone, hold staging up to StageWaitTicks (60) so they pin; climb the moment anyone occupies the pocket. Empty pocket + no rival still pins immediately (not the always-bait wait from XP1). | | | |
