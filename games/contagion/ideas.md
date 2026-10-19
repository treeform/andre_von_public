# Contagion — Likho

Policy: **Likho** (`likho`) — one-eyed spirit of misfortune — plague.

Coworld: `cow_ad51853a-4332-4b88-8b10-ccca54e8410d` (coworld name `contagion`)

Contagion: six governors, one epidemic, nine roads. Six LLM-piloted governors each run one region of a six-node road network (the 6-cycle plus its three long diagonals, so every region has exactly two main roads and one back road and no seat is structurally stuck) for twenty weeks. Every week, simultaneously, each governor sets three dials - lockdown 0..4, testing 0..3, and one border gate 0..2 per road - may address the whole table in one short non-binding message, and may wire up to 200 credits of aid to other regions. The week then resolves: dials latch and each road takes the TIGHTER of its two ends as its effective gate; talk queues for next week; aid settles immediately and unconditionally; the infection crosses every road whether or not it was closed, because a road sealed at both ends still passes 12% of its traffic; the economy pays for the dials and for the sickness; and the dead are counted, at triple the rate once hospitals are over capacity. A governor never sees the true case counts, not even its own - only REPORTED cases, which are its detection rate times the truth (15% at testing 0). Every region's testing level is public, so de-biasing anyone's reported number is intended play. A seat's SCORE is its region's accumulated GDP minus two credits per death; it can be negative, because an uncontrolled epidemic loses more than the region ever earned. All arithmetic is integer parts-per-million, which is what lets the static wasm replay viewer re-derive every frame in the browser and check it field-for-field against the record. The game is LLM-driven: every week the server sends each seat's policy prompt plus its view to Claude as ONE parallel batch, so A POLICY IS JUST A PROMPT - build one by reusing the published player runnable and setting the PLAYER_PROMPT environment variable to your strategy. Two scripted baselines (sentinel, the threshold dial policy, and laggard, the leaky neighbour that never tests and never closes) play any seat that registers as scripted - and every seat when no LLM credentials are available, so episodes always complete.

## Leagues

- `league_53d9ccfb-c943-4b5c-a89f-b9b149365df1` — Contagion

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `contagion-player` — Contagion Prompt Player: The reference Contagion policy: delivers its PLAYER_PROMPT (or a default suppress-then-reopen strategy in words) to the game and spectates until the final frame. Field your own policy by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/contagion-player`)
- `contagion-sentinel` — Contagion Sentinel Baseline: The scripted threshold baseline as a fieldable policy: de-bias your own reported cases, step lockdown and testing at fixed prevalence thresholds, gate each road against its neighbour's de-biased estimate, never talk and never send aid. The game server plays it deterministically, no LLM involved, and it is also the universal fallback move. (run: `/bin/contagion-player`)
- `contagion-laggard` — Contagion Laggard Baseline: The scripted leaky neighbour: testing always 0 (so it under-reports by 6.7x and never isolates), all gates always open, and lockdown 3 for exactly three weeks once its own blind estimate finally crosses 4%. Late, blind, and expensive for everyone downwind - the pressure the other five seats are playing against. (run: `/bin/contagion-player`)

## Baseline

Default and strongest example: `sentinel` (PLAYER_SCRIPTED=sentinel) — grid-swept threshold dials (lockdown 0.1/0.4/1.25/3.0%, testing 0.1/1.25%, roads 0.016/0.08%; `tests/test_sweep.nim` argmax), also the certification player and per-week fallback. `laggard` is the deliberately leaky foil. Likho (`likho/likho.nim`) is a thin prompt seat: it sends `{"type":"prompt","prompt",...}` on connect and again after `welcome`, then spectates. **Default is `PLAYER_SCRIPTED=sentinel`** (empty prompt while a baseline is named). `decideAll` plays scripted whenever `scripted != skNone` (src/contagion/llm.nim). Empty `PLAYER_SCRIPTED` restores the operator prompt (de-bias, testing-2 / lockdown-ladder, per-neighbour gates, conditional aid). Env still overrides (`sentinel` | `laggard` | empty). Upload secret-envs: none for the sentinel default. LLM override needs `--secret-env USE_BEDROCK=true`. Sim checked at coworld 0.1.1 / `74dbfb230c8308216a4f34342b298e6a80eaf7dc`.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Tune the lockdown ladder thresholds (0.1/0.5/2%) against sentinel fields: sentinel's fixed thresholds may over- or under-lock; sweep one boundary at a time.
- Aid discipline experiment: current prompt pays hot neighbours up to 200/wk. Try a no-aid variant to measure whether aid actually buys fewer imported infections than it costs.
- Variant-week detector: add an explicit "if confirmedNew rises 2 weeks running on unchanged dials, assume the 1.25x variant landed and add one lockdown level" line; measure weeks 8-14 death delta.
- Endgame reopening: test reopening at week 16 vs 18 when clean — the prompt currently reopens on estimate < 0.05%; earlier reopening banks more GDP but risks a late seed from a leaky neighbour.
- Talk-driven coalitions: have Likho propose a table-wide norm in week 1 (everyone testing >= 2) and name defectors weekly; measure whether the field's dials actually respond.
- Border spillover awareness: never close a road against a region below 0.2% (their 5/15 spend spillover is dead weight); check if that saves enough to matter vs the leak risk.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Field built-in `sentinel` instead of the LLM prompt. Field.md 2026-08-27: 4 rated, leader daveey-1 1069.4 wr 0.36; we are #6 of 6 at 815.6. Active policies include contagion-outpost-sentinel. Sentinel is the grid-swept threshold baseline (lockdown cuts 0.1/0.4/1.25/3.0%, testing 0.1/1.25%, roads 0.016/0.08%; tests/test_sweep.nim argmax x0.25..x4, 5 seeds). Our prompt was factually wrong vs that sweep: close roads at 1.5% (18x too late vs 0.08%), L1 on a clean region (sentinel uses L0 below 0.1%), L4 on hospital "strained" (IFR still 0.8% until 25k), and it spends aid (sentinel never does; aid is a direct ledger loss). Server `decideAll` plays scripted whenever scripted != skNone (src/contagion/llm.nim). Scripted/code A/Bs have won; prompt rewrites have lost. | default PLAYER_SCRIPTED to `sentinel` and send an empty prompt while a baseline is named (env still overrides; empty PLAYER_SCRIPTED restores the operator prompt) | | | |
