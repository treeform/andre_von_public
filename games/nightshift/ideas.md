# Nightshift — Nochnitsa

Policy: **Nochnitsa** (`nochnitsa`) — night spirit.

Coworld: `cow_21358a31-f60a-414c-860b-a71ae0a73163` (coworld name `nightshift`)

One Night Ultimate Werewolf adaptation: a hidden-role social-deduction coworld that benchmarks modeling other minds under time pressure, across repeated scenes with a full end-of-scene reveal and a scoring-inert solo debrief. League play seats 3-10 players with a random role set; table size and roles are unknown until scene_start, so build general policies.

## Leagues

- `league_f754def9-4850-43b9-af35-aebb9e98ebc9` — Nightshift

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `clockwork` — Clockwork: Scripted, non-LLM baseline. Deterministic given the episode seed; makes forced and seeded-random legal moves, claims honestly (Villager when dealt Werewolf/Minion), bids to speak once, never kill-votes a known fellow werewolf. (run: `python -m nightshift.players.clockwork`)
- `haiku-baseline` — Haiku Baseline: Minimal LLM player over AWS Bedrock (model id from BEDROCK_MODEL). Honest as village; role-plays a claimed role as werewolf. Bounded model calls with safe default fallbacks so throttling never hangs the episode. (run: `python -m nightshift.players.haiku_baseline`)

## Baseline

Default example is `clockwork` (scripted, deterministic); strongest is
`haiku-baseline` (Bedrock LLM). Our `nochnitsa` is a Nim rewrite of the
clockwork shape as a command player: answers EVERY mandatory window
immediately (liveness is the qualifying gate), preregisters a
deterministic legal night plan per role (seer views a player, robber
robs, troublemaker swaps the two neighbours, drunk/werewolf take a
scene-rotated center card, everyone else declines), claims honestly in
speech (Villager when dealt Werewolf/Minion), bids 1 point to speak once
per scene, and kill-votes the circle-vote convention (seat+1 mod N)
skipping self and known fellow wolves parsed from `night_result`.
Village with a viewed werewolf card (Seer / copied-Seer) kill-votes that
seat instead — a circle table already puts 1 on everyone, so the extra
vote is the village win. Seer sightings are not stuffed into
`knownWolves` (that used to skip the wolf and break circle onto a
villager). Robber who drew a werewolf stays wolf-aligned and still
circles.
Strategize / post-night / debrief windows are liveness-exempt and
skipped. Zero model calls — upload needs NO secret-envs.

Protocol-confidence caveats (source repo Metta-AI/coworld-nightshift is
private, 404; reconstruction from docs/protocol_player.md):
- `legal_actions` shape in `night_preregister_request` is unknown; we
  build the role-schema reply and fall back to the first legal action
  object when our key-shape isn't among them.
- Werewolf `initial` preregister is sent as a lone-wolf center peek on
  the assumption plans apply only when legal; if that defaults, switch
  to `{mode:"decline"}`.
- Night observation schema is still a heuristic: partner lists
  (`seats`/`werewolves`/`partners`) vs a werewolf `role`/`card` on a
  `target`/`player`/`seat`. Seer sightings go to `seenWolfSeat`, not
  `knownWolves`.
- We append `protocol_version=0.4.0` to `COWORLD_PLAYER_WS_URL` if the
  platform URL lacks it.
- `notebook_ack` accumulation + artifact upload on final is NOT
  implemented (scoring-inert).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Validate the container against `examples/player-template` before any
  submit; confirm zero defaults in an intro-3 XP run (liveness audit is
  in results `scenes[].defaults`).
- Log the raw `night_preregister_request.legal_actions` payload from a
  hosted run and replace the shape-guess with exact schema handling.
- Use night information in the kill vote: dealt Seer that saw a
  werewolf, or Robber now holding werewolf, should break the circle
  vote and nominate/vote the wolf (and bid max points to speak).
- As dealt Werewolf, claim a safer specific role (e.g. Villager vs
  Mason depending on role_set) and vote the seat that claimed Seer —
  clockwork-honest villager claims are exploitable by any reader.
- Track claims from `speech_delta` text (cheap keyword parse) and vote
  contradictions: two Seer claims => vote the later claimer.
- Spend the debrief/strategize windows writing structured notebooks and
  upload on final so hosted replays become auditable for us.
- Doppelganger: copy the seat most likely to be village (avoid copying
  the previous scene's revealed wolf seat) instead of the fixed
  neighbour pick.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| - | fleet/triage candidate v2 | see git history | triage batch | paired vs champion | REVERT: 0.80->0.50 t=-1.15 |
| 1 | village kill-vote a seer-seen werewolf (circle tables already put 1 on everyone; the extra vote is the village win) | stop stuffing seer sightings into knownWolves (that skipped the wolf and broke circle onto a villager); parse night_result role+seat; village-aligned seats vote seenWolfSeat | | | |
