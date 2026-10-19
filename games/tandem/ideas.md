# Tandem — Ivanushka

Policy: **Ivanushka** (`ivanushka`) — Alyonushka's brother — the inseparable pair.

Coworld: `cow_77d94979-f003-494d-8c60-6bd97b97b9db` (coworld name `tandem`)

Two cogs, one couch, no channel: they are rigidly gripped to opposite handles and must carry it through a procedurally generated warehouse. The couch obeys the SUM of their forces, so coordination happens through the physics itself. A policy is just a prompt.

## Leagues

- `league_50c18e88-ed54-4cd7-be36-4748d79b5a9b` — Tandem

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `baseline` — Tandem Porter Baseline: Strain-arbitrated scripted carrier; no LLM. It heads for the next doorway centre, lines the couch axis up with the corridor, braces in the gap and yields whenever the force it feels opposes where it wants to go. (run: `/bin/tandem-player`)

## Baseline

The only example player is `baseline` (Tandem Porter Baseline), registering scripted `porter` — the strain-arbitrated reference carrier and the fallback for every failure mode; `mule` is the deliberately weak second filler. Our `ivanushka` is the Sprite v1 thin player in Nim: registration sent on connect and re-sent after the first frame, Ready (0x85) after every binary frame, no inputs ever. **Default is `PLAYER_SCRIPTED=porter`** (empty prompt so a non-empty prompt does not flip the seat to LLM). Empty `PLAYER_SCRIPTED` restores the operator prompt (doorway-centre drive, align before 1.5 m, brace in gaps / over 600 N, yield-or-lead). Env still overrides (`porter` | `mule` | empty). Upload secret-envs: none for the porter default. LLM override needs `--secret-env USE_BEDROCK=true`.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- The cross-play partner is usually `porter`: study what porter does (yields when opposed, heads for doorway centres) and tune the prompt to LEAD confidently, since porter will follow a decisive line.
- Try a pure-follower variant (yield 0.7 baseline): two leaders fight, but a follower paired with anyone decisive should deliver; compare cross-play means.
- Twist discipline: a positive twist from BOTH seats is a pure couple — prompt the fore seat (Cobalt, slot 0) and aft seat (Rust, slot 1) differently via role detection from the welcome frame data in the sensor JSON, if the view exposes which handle you hold.
- Speed/condition arithmetic in the prompt: speed = clamp(2 - t/par, 0, 1), so once t > 2*par speed is 0 and ONLY condition matters — crawl through the remaining doors braced.
- Drop recovery: after a drop (couch on the floor, 2 s), the right order is hold still with brace up, not re-shove; add an explicit post-drop turn to the prompt.
- Scrape hysteresis: one turn of drive-away-from-wall may overcorrect into the opposite wall in narrow corridors; try half-effort along-corridor instead of away-from-wall.
- Shorten the prompt to ~150 words and A/B: the sensor frame already carries the situation; fewer words may cut fallbacks and latency.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Field the published scripted `porter` instead of the LLM prompt. Leader is `co-gas-tandem-porter-relhalpha` (wr 0.55); richard also fields porter. Score is fully cooperative (identical number both seats); the league ranks by mean score and the usual cross-play partner is porter. Server treats any non-empty prompt as an LLM seat and ignores `scripted` (docs/protocol_player.md). Porter is the strain-arbitrated carrier: doorway-centre drive, axis align, brace in gaps, yield when the felt force opposes. The v1 prompt lets a seat "commit hard" when strain opposes, which fights a porter partner and costs condition; LLM turns also risk fallback/latency. Scripted/code A/Bs have won; prompt rewrites have lost. | default PLAYER_SCRIPTED to `porter` and send an empty prompt while a baseline is named (env still overrides; empty PLAYER_SCRIPTED restores the operator prompt) | | | |
