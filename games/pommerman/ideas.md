# Pommerman — Tugarin Zmey

Policy: **Tugarin Zmey** (`tugarin`) — the fiery villain — explosions.

Coworld: `cow_360a82dc-10cc-4b8c-8449-d9f1c227da53` (coworld name `pommerman`)

Pommerman as a Coworld. Four bombers stand in the four corners of an 11x11 walled grid packed with wooden walls, seated as two teams of two on the diagonals by the server. Bombs clear wood and kill; wood hides power-ups that give extra bombs, longer blasts and the ability to kick a bomb down a lane. Every four ticks each seat issues its bomber ONE order and sends its PARTNER two integers in 1..8 that the game gives no meaning and the opposing team never sees - an emergent-language channel between two policies that were seated as partners by the ladder and have never met. At tick 96 and again at 120 the outer rings turn to rigid wall and crush whatever stands on them, so the fight is forced into the middle and closes. The team score is exactly zero-sum, so no two seats can raise their joint total by cooperating across the table.

## Leagues

- `league_7b53400d-b780-4024-924a-59bc2818dc8d` — Pommerman

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `sapper` — pommerman-sapper: The published scripted default and the server-side fallback: bomb an enemy in a clear lane, else bomb the wood you are standing beside, else walk to the nearest power-up, else break toward the middle, and head inward before the rings close. Sends a real radio pair every turn: ammo plus one, and enemies within four cells plus one. (run: `/bin/pommerman-player`)
- `camper` — pommerman-camper: Deliberately weaker and different in shape: it only bombs an adjacent enemy or a wall it has two safe exits from, hides the rest of the time, and sends [1, 1] every single turn. The silent partner is the control against which 'did the radio matter?' is measured on the ladder. (run: `/bin/pommerman-player`)

## Baseline

The default (and server-side fallback) example is `sapper`; `camper` is the
deliberately weaker silent-partner control. Both are scripted names for the
same thin `/bin/pommerman-player` seat — this game is a PROMPT SEAT: the
seat sends one Sprite v1 chat frame `{"policy","prompt","scripted"}` and
then only acks binary frames with 0x85; the game container runs the LLM
every 4 ticks (anthropic_api_key is injected into the GAME pod, so **no
USE_BEDROCK secret-env** on upload). **Tugarin Zmey** (`tugarin/`) follows
the upstream `src/pommerman_player.nim` wire behavior exactly (bounded
dialling, registration re-sends for the first ~10 frames, exit 0 on a dead
socket, bounded reconnects) and embeds a crafted operator prompt (3.3k of
the 4k rune cap): farm wood/power-ups turns 1-12, convert an equipment edge
into hunts 13-24, centre before the ring collapses at ticks 96/120; a fixed
[intent, zone] radio code with 3 = "my bomb is live", zone checkable
against bombers[]; notes used as memory for enemy pickups and the code.
Override with secret-env PLAYER_PROMPT, or PLAYER_SCRIPTED=sapper|camper.

Protocol source: cogame-pommerman docs/PROTOCOL.md, RULES.md, RADIO.md +
src/pommerman_player.nim (fetched via gh api; blob stubs 404 anonymously).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Radio scheme A/B: replace the 8-intent code with sapper-compatible
  [1+ammo, 1+enemies-within-4] so a scripted partner's pairs decode for
  free and a sapper partner "understands" ours by coincidence.
- Anti-camper detection in the prompt: if the partner pair has been
  constant for 5+ turns, stop budgeting for coordination and play the 1v2
  line (centre control, never split the enemies between us).
- Collapse-timing pressure: from turn 20, deliberately bomb the ring-1
  cells enemies retreat through so their escape from the tick-96 collapse
  walks into flame.
- Kick-priority farming: weight the orbit-5 kick power-up above +range in
  the prompt's farm phase; `kick dir` down a corridor is the only ranged
  attack in the game and the controller refuses no kick orders.
- Say-channel psyops: use `say` (spectator-visible, also unread by
  enemies' prompts? verify in replay) purely for dash legibility; keep
  notes for real state so the 200-rune cap is never wasted.
- Prompt-length ablation: cut the prompt to ~1500 runes (phases + radio
  code only) and measure fallbackTurns/ordersRejected in results — a
  shorter prompt may cut 12 s attempt-1 timeouts.
- Endgame draw logic: when teamAlive is even and score-by-wood is ahead,
  explicitly order hide near centre and radio 8 — banking the wood
  tiebreaker beats a coin-flip trade.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| - | fleet/triage candidate v2 | see git history | triage batch | paired vs champion | REVERT: 8.40->-8.40 t=-0.21 |
| 1 | scoring-math bank/hunt | prompt: 100 is living-majority not wipe; hide if ahead, hunt if behind (wood never beats a 1-alive lead of 120) |  |  |  |
