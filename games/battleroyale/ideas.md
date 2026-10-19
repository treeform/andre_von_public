# Battleroyale — Koschei

Policy: **Koschei** (`koschei`) — the deathless — last one standing.

Coworld: `cow_a2855632-b79c-4dcf-9dda-8d6eaf726696` (coworld name `battleroyale`)

Battle Royale: a free-for-all last-one-standing shooter, AI bots only. Every seat is its own team with its own color - there are no allies. N players (2-16) spawn on a large generated arena's evenly spaced ring; a deterministic seed-derived offset rotates seat ownership of the unchanged pads each episode. Players have 20 hit points and ONE life: there is no respawn, so a death is final and the episode ends when one player is left standing (or the clock expires, in which case the deepest survivor ranks first). A shrinking circular safe zone squeezes the board over 150 seconds down to a 3% floor of its area; standing outside it costs a hit point every 48 ticks, and stepping back inside drains that exposure rather than resetting it. The tight final floor herds late survivors into final engagements, while gradual outside damage limits ring-only executions. In the late game, when three or fewer players remain, baseline bots close on the nearest living enemy while still respecting ring safety and normal aim/fire gates. Arena-anchored deterministic loot bands keep low guns broad across the board, mid guns intermediate, and heavy guns in the center; the non-gun center cluster remains compact even at the 3% floor. Scoring is per player: kills, assists, survival time and podium placement. Combat, vision and movement are inherited from Coworld CTF: aim is decoupled from movement and carries a fog-of-war vision cone, guns are hitscan with a trigger windup, a fixed 1050px range and lightly fuzzed aim, friendly fire is moot because everyone is an enemy, and unseen gunfire is heard as a jittered sound ring rather than pinpointed. Players can shout 10-character messages heard within a fifth of the field, so proximity diplomacy (and betrayal) is playable. Player observation coordinates are 1x map scale and the grenade throw is player-input bit 7 / value 128 (see docs/PROTOCOL.md).

## Leagues

- `league_b88a269b-0de7-4723-b1c7-06dab50fe61d` — Battle Royale

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `baseline` — baseline: Minimal sprite-protocol baseline bot with an FFA doctrine: treat every visible actor as an opponent, contest the center loot, track and lead targets, and respect the ring. Image placeholder is replaced at deploy time. (run: `/bin/baseline`)

## Local baseline

~/p/coworld-battle-royale — local repo.

## Baseline

- Default and strongest example is `baseline` (the only example player) —
  the upstream bot from ~/p/coworld-battle-royale players/baseline/: a full
  command player with a persistent world model (eroded walkability nav grid
  with a Dijkstra cost field, cover-aware path costs, fogged-enemy memory),
  an FFA doctrine (everyone is an enemy, contest the center loot bands,
  track and lead targets, respect the shrinking ring, close on the nearest
  enemy when three or fewer remain), and decoupled aim control.
- Koschei IS that source, copied to `koschei/koschei.nim` with its
  dependency cone vendored beside it: the pinned bitworld `spriteprotocol`
  (trimmed of pixie/palette; keeps ButtonC = grenade bit 7) plus `binny`,
  `supersnappy`, the lock-pinned `whisky` (exports `socket` for the
  TCP_NODELAY tweak), the shared `labels` vocabulary verbatim, a
  `sim_types` stub holding just the contract constants (GV45), a no-op
  `artlog` stub (upstream telemetry needs zippy+curly; gameplay-neutral by
  contract), and Bedrock taunts compiled out (`-d:taunt` would need the
  upstream taunts module).
- It plays Sprites Off (0x87, state and labels only), and reads
  `COWORLD_PLAYER_WS_URL` (falling back to `COGAMES_ENGINE_WS_URL`). Many
  knobs are env-tunable at runtime (`CTF_BOT_FFA_DOCTRINE`,
  `CTF_BOT_FFA_RETREAT_HP`, `CTF_BOT_FFA_LATE_CLOSE`, pact/hunter/loot-trip
  ranges), so A/Bs can ship as `--env` changes without code edits.
- Upload: plain command player, `--run /bin/policy_player`, no secret envs
  (no USE_BEDROCK needed with taunts compiled out).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Doctrine A/B via `CTF_BOT_FFA_DOCTRINE` (hunter vs default band doctrine):
  hunter is already the unset default (kept vs legacy on an older
  nearest-MRR field). Rush/passive defaults lost or trended worse.
- Retreat threshold sweep: `CTF_BOT_FFA_RETREAT_HP` (default 6 of 20) —
  one life makes over-retreating cheap and under-retreating fatal. Queued
  behind the pact re-test: hunter already heals on any HP loss and gates
  chase with `CTF_BOT_FFA_HUNTER_PURSUIT_MIN_HP` (also 6), so this knob
  barely moves the current default.
- Ring-edge ambush: bias the radial band toward the safe-zone boundary in
  mid game so inbound stragglers walk into our cone while we stay inside.
- Third-party discipline: when two enemies are exchanging fire in view,
  hold fire outside ~500px and engage the survivor (kills go to the last
  damager, so vulturing is score-efficient). Pact doctrine is the
  already-coded version of this (experiment 1).
- Grenade (ButtonC/bit 7) usage in the endgame floor: at the 3% ring the
  final brawl is point-blank — lob on cooldown at the nearest track
  instead of holding a fist/low-gun duel.
- Pact window tuning: `CTF_BOT_FFA_PACT_WINDOW_*` (fraction 0.35 of the
  150s ring shrink, ~52s; `PACT_WINDOW_SEC` 0 = use the fraction). Old
  sparse field never produced `pact_converge`, so the window was not
  isolated. Re-tune only if experiment 1 actually fires the branch.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Pact doctrine re-test on the dense field. Unset doctrine was hunter. field.md (2026-08-27) is 20 rated players / 154 entrants, us #12; today's ladder is ~24 unique policies filling 12–16 huge-map seats with aggressive top policies (meyer kite/finisher, Jordan, Ryan's shadow) rather than the old nearest-MRR baselines. More hunters closing distance → earlier fights → visible two-player brawls, which is the only state pact can act on. Pact keeps hunter arm/pursuit/late-close and, for the first 0.35 of ring shrink, focuses the weaker of a seen brawl and skips the partner. Last damager gets the kill, so third-partying is score-efficient; no visible brawl falls through to hunter (floor = current default). Old pact default was measured at-or-under hunter because the sparse field produced zero `pact_converge` ticks. Retreat HP 6→N is the other density candidate, but hunter ignores `CTF_BOT_FFA_RETREAT_HP` (heal-any-damage + separate pursuit-min-HP=6), so it would not actually peel. | unset `CTF_BOT_FFA_DOCTRINE` default hunter → pact (pact window left at 0.35 / 0s) | | | |
