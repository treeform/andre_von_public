# Gen Generals Io — Suvorov

Policy: **Suvorov** (`suvorov`) — the general who never lost a battle.

Coworld: `cow_ce7b1692-497a-4c76-ac6b-bc9b70a7c39b` (coworld name `gen-generals-io`)

Four commanders, one crown each, on a seeded four-fold-symmetric grid. You see only the tiles you own and the ring around them. Take a rival's crown and you inherit everything they own.

## Leagues

- `league_03508cde-90d2-43fa-a963-32265afd4737` — Gen Generals Io

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `sprawl` — gen-generals-io-sprawl: The strong simple generals.io opening, held all game: expand until you hold a quarter of the board, then push at the nearest enemy tile. It is also the server-side fallback for any turn an LLM seat cannot answer. (run: `/bin/gen-generals-io-player`)
- `crown` — gen-generals-io-crown: Buys map knowledge early and pays for it in land: two scouting turns in four, twenty armies parked on the crown, and a raid the moment a rival crown is known. (run: `/bin/gen-generals-io-player`)

## Baseline

`sprawl` is the default, the per-turn fallback and the no-show driver
(defend when threatened, expand under a quarter of the board, else attack
nearest); `crown` scouts two turns in four and raids known crowns. A policy
here is JUST A PROMPT: the seat sends one Sprite v1 chat frame (0x81)
carrying `register` and then only acknowledges with Ready (0x85); the GAME
server holds the anthropic_api_key and asks Claude for one plan object
(intent/target/reserve/cities/scouts/note) every eight turns, executed by a
deterministic captain.

**Suvorov** (`suvorov/`) is a prompt seat on the alyosha Sprite v1 pattern,
with registration re-sent ~1 s apart for the first ten seconds (joins are
slot-sequential). The prompt (v2): expand opening through turn 32 with
scouts 2 / cities never / reserve 0 (buy known_generals; a seen crown
never forgets), raid the moment `known_generals` is non-empty (captain
raid walks nearest seen crown and ignores target), gather-once if the
target army is >2x ours, hard defend on `your_general.threatened`,
trail/lead split past turn 190.

Upload secret-envs: none — the game pod holds the LLM. If a league round
shows the seat silently playing sprawl, retry with USE_BEDROCK=true.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Priced second raid: after a failed raid the target crown holds the
  difference — prompt the follow-up raid immediately while the garrison is
  still spent, instead of retreating to gather.
- City-toll timing: sweep `cities` never/cheap/always in the opening 30
  turns — 40 armies for +1/turn pays back in 40 turns, so `always` may only
  win in the first half.
- Reserve as army-count function: reserve = crown garrison of the biggest
  visible neighbor stack, not a constant — exact `amount` moves make this
  precise.
- Growth-pulse raids: the periodic +1 lands every 25 turns; time gathers to
  finish just after a pulse so the raid stack carries it.
- Standing-based target switching: raid whoever is 4th on land, defend
  against whoever is 1st — test vs crown, which raids nearest-known blindly.
- Blitz-module variant prompt: 12x8 and 160 turns compress everything; test
  whether the turn thresholds (32/190) should scale by maxTurns.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Scout-then-raid on the published leader's schedule. Dash 2026-09-01: MMR #1 daveey-1 gen-generals-io-regicide 1330 wr 0.60; mean-score #1 richard compound-scout 0.72 wr 0.74; us suvorov #4 757 wr 0.25 (17-73 vs regicide, 22-68 vs compound-scout, 54-36 vs landgrab #5). Crown capture inherits all land (armies halved) and alive is the first scoring key; land-first is last on this field. Sim v0.1.1: scouts is a share of turns (`turn mod 4 < scouts`) and raid ignores target (nearest seen crown). | Opening scouts 1→2, cities never, reserve 0 through turn 32; raid the moment known_generals is non-empty (drop garrison-plus-distance wait). Defend/endgame unchanged. | | | |
