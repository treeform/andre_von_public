# Commons Family — Bereginya

Policy: **Bereginya** (`bereginya`) — protector spirit of hearth and commons.

Coworld: `cow_73578681-ae8b-4ec8-b0ef-9622d639c09a` (coworld name `commons_family`)

Six cogs share one destructible commons for twenty simultaneous rounds. Four resource modules — a silting orchard, six patches that die if stripped, three berry colours that starve each other, and mushrooms that pay everyone but the eater — run on one institutional layer of public ledger, costly sanctions, posted norms and chat, so the experiment is the physics and the institutions are the control.

## Leagues

- `league_a95d0e60-1042-4981-bcdc-ead449bfa783` — Commons Family

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `commons-prompt` — Commons Prompt: The reference prompt policy: an LLM seat whose whole strategy is its standing orders. (run: `/bin/commons-family-player`)
- `steward` — Steward: Takes a sustainable share and maintains when the resource needs it. The fallback every prompt seat drops to. (run: `/bin/commons-family-player`)
- `cleaner` — Cleaner: Spends one effort unit on the public good every round and stewards with the rest. The pure contributor, and exploitable. (run: `/bin/commons-family-player`)
- `punisher` — Punisher: Stewards, and pays to burn the worst over-taker on the public ledger. (run: `/bin/commons-family-player`)
- `free-rider` — Free Rider: Takes the maximum every round and never maintains. The tragedy, distilled. (run: `/bin/commons-family-player`)
- `random` — Random Cog: Uniform legal decisions. The maximum-variance control. (run: `/bin/commons-family-player`)

## Baseline

`steward` (sustainable share + maintain when needed) is the default fallback every prompt seat drops to and the strongest all-round scripted baseline; `punisher` adds costly deterrence, `free_rider` is the tragedy control. Bereginya (`bereginya/bereginya.nim`) is a thin prompt seat: it sends `{"type":"prompt","prompt","scripted":""}` on connect and again after `welcome`, then spectates — all six seats' decisions go out as one parallel LLM batch in the game container. The crafted prompt (kept under the 1200-rune cap) is a conditional cooperator with per-module lines: cleanup 2/1 effort split with river triage, never-strip patch discipline that flips to salvage when patches die anyway, single-colour massing in allelopathic, eat-1-red (never blue) in mushrooms, and a strict sanction budget (worst repeat over-taker only, max twice, never consecutive). `PLAYER_PROMPT` / `PLAYER_SCRIPTED=<baseline>` env overrides supported. Upload needs `--secret-env USE_BEDROCK=true` or the seat plays steward.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Sanction budget sweep: current cap is 2/episode. Against free_rider-heavy fields deterrence may pay (their -3 vs our -1); test cap 0 vs 2 vs 4 on mushrooms and harvest.
- Harvest salvage trigger: "take 3 when patches are dying anyway" needs a concrete trigger (2+ patches dead, or any patch seen at <=1 twice); vague triggers make models hesitate — pin it and measure.
- Mushrooms opening: green vs blue open. Blue is the planner optimum with reciprocators but pays us 0 vs defectors; try opening blue only when round-1 chat shows 3+ cooperative messages.
- Chat quota posting: measure whether posting a numeric quota in round 1 actually shifts the field's extraction vs staying silent (the norm_text may already do this work).
- Allelopathic favourite-colour handling: eating own favourite pays double but fights the massed colour; test "favourite only when it is also the massed colour" vs current looser line.
- Cleanup river hysteresis: add "clean until regrowth resumes plus one round" to avoid oscillating between clean-starved and clean-wasted rounds.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | mushrooms: never blue, eat 1 red | standing-orders mushrooms line: red +1 to you / green +0.33 / blue 0; eat 1 red (green if reds gone), never blue, never eat 3. Was "open green then go blue vs cooperators" — that is planner welfare, not league score: blue pays the eater 0 and 0.6 to each rival. Field leaders are cooperative ledger-wardens; donating via blue cannot beat them. Eat 1 so freeze is 0 and extracted matches a steward, so quota-punishers do not single us out. | | | |
