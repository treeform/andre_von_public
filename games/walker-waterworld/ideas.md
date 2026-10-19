# Walker Waterworld — Vodyanoy

Policy: **Vodyanoy** (`vodyanoy`) — the water spirit.

Coworld: `cow_36a12905-cdf6-4c9e-8bc4-2c0e541b9fb1` (coworld name `walker-waterworld`)

Four thruster skimmers feel for drifting plankton with 2.40 m sensors; nothing is caught unless two of them touch it at the same instant.

## Leagues

- `league_69fe3c37-8208-4e14-b575-331e1d018d9b` — Walker Waterworld

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `baseline` — Waterworld Shoal Baseline: Pair-and-hunt scripted skimmer: keep your partner close, take plankton together, back off poison. No LLM. (run: `/bin/walker-waterworld-player`)

## Baseline

The only example player is `baseline` (Waterworld Shoal Baseline), registering scripted `shoal` — pair-and-hunt, also the no-registration default, the two-failure fallback and the no-show driver; `drifter` is the second scripted name. Our `vodyanoy` is a prompt seat: it registers over the Sprite v1 chat channel (0x81 + u16 length + JSON, re-sent for the first ~10 s of frames), answers every binary frame with Ready (0x85), sends no inputs, and exits 0 on socket close. The prompt is a rendezvous convention: partner = nearest skimmer, hunt together when both can reach a plankton, HOLD on sensed plankton when the partner is far (their escort rule brings them), escort when sensing nothing, avoid poison inside 1.0 m, and throttle discipline (0.4-0.5 cruise, 0.8 only on final approach). `PLAYER_PROMPT` / `PLAYER_SCRIPTED` env overrides. Upload needs `--secret-env USE_BEDROCK=true` or the seat silently plays scripted.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Verify the hold-on-plankton rule against the nibble re-arm: sitting on food nibbles once (+0.05) then blocks until 0.60 m separation — check in replays whether hold keeps contact (fine, the wait is for the partner) or jitters and re-nibbles.
- Pairing stability: nearest-skimmer pairing can flap when distances are close; try a fixed-by-alias convention (SKIM-1 pairs SKIM-2, SKIM-3 pairs SKIM-4) and compare cross-play means against mixed fields where the rival policies do not share it.
- Lead_ticks tuning: plankton travel 0.67-0.91 m/s and bounce off walls; 12 ticks (0.5 s) of lead may overshoot near walls — try 6 near walls, 18 in open water.
- Poison-aware standoff schedule: standoff 0.6 while closing vs 1.2 cruising is a guess; sweep 0.4/0.8/1.6 in XP batches and read the poisonHits and thrust decomposition from the replay's reward block.
- Early-exit hunting: at 20 captures the run ends and banks max score; prompt the endgame — when captures >= 17, all four converge on the densest plankton area at high throttle since thrust cost stops mattering.
- Cross-play robustness: our rules assume rivals escort like shoal; add a fallback — if the partner has ignored your hold for 2+ turns, switch partner to the second-nearest skimmer.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | fixed xor-1 pairing (match tandemhunt/shoal); nearest-neighbour is not symmetric | prompt: partner = SKIM-1↔2 / SKIM-3↔4 every turn, never nearest |  |  |  |
