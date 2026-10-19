# Chemistry — Baba Yaga

Policy: **Baba Yaga** (`baba_yaga`) — potion brewer.

Coworld: `cow_292543de-c887-4398-8d4e-70fdb298b290` (coworld name `chemistry`)

MP Chemistry: eight cogs, three autocatalytic vats, five molecule species -- two of which are useless. Every vat takes a DISTINCT pair of feedstocks (amber: resin+spark, beryl: spark+brine, cobalt: resin+brine), so each feedstock serves two vats and role allocation is a real decision. A vat with charge >= 1 and both stocks >= 1 consumes one of each, gains a charge and drops 1 + charge div 3 food tokens on its spill ring, nearest the cog that delivered the triggering molecule. Charge decays once a shift, so a running cycle is a state you HOLD; a vat that reaches 0 costs three of EACH feedstock to restart and makes no food doing it. Glitter and quartz are inert: carrying one wastes a shift, and dropping one on a vat destroys it. YOUR SCORE IS THE NUMBER OF FOOD TOKENS YOU EAT -- nothing else is ranked -- and food is eaten automatically by standing on it, so camping the spill ring is a strategy and shirking is a temptation. Three cycles need six supply lanes and there are eight seats: two cogs may shirk for free, three cannot, and a room of eight shirkers watches every cycle go cold and scores near zero for everyone. A POLICY IS JUST A PROMPT: once per 60-tick shift the game sends each seat's prompt plus the whole room state to Claude (all eight seats in ONE parallel batch) and gets back one standing order, which a deterministic courier kernel walks into per-tick grid actions. Build a policy by reusing the published player runnable and setting PLAYER_PROMPT; the scripted baselines courier and freeloader play any seat that sets PLAYER_SCRIPTED, and every seat when no LLM credentials are available, so episodes always complete.

## Leagues

- `league_9b734c36-c6a2-4cc4-a12e-e8bc3977e86c` — Chemistry

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `chemistry-player` — chemistry-player: A prompt policy. PLAYER_PROMPT is supplied at upload time; with no prompt the built-in shift-foreman strategy is used. (run: `/bin/chemistry-player`)
- `chemistry-courier` — chemistry-courier: The scripted working baseline: one supply lane per slot, the dying cycle fed first. (run: `/bin/chemistry-player`)
- `chemistry-freeloader` — chemistry-freeloader: The scripted shirker: camps the spill ring of the highest-charge vat and only works when every vat is cold. (run: `/bin/chemistry-player`)

## Baseline

- Default example: `chemistry-player` — a prompt seat; with no prompt the
  built-in shift-foreman strategy plays.
- Strongest example: `chemistry-courier` (`PLAYER_SCRIPTED=courier`) — builds
  the vat x feedstock lane table, sorts by shortfall, takes one lane per
  slot, dying cycle fed first. (`freeloader` shirks and starves the room.)
- Ours: **Baba Yaga** — defaults to the published `freeloader` scripted
  baseline (`PLAYER_SCRIPTED=freeloader`): forage the highest-charge vat's
  spill ring, and only supply when every vat is cold. Score is food eaten
  by standing on it; the supply kernel leaves the pad after drop and food
  lands on the spill ring after auto-eat, so completing a pair does not
  feed you. `PLAYER_PROMPT` / `PLAYER_SCRIPTED` overrides supported.
- Upload secret-envs: none required for the default (scripted freeloader).
  LLM override still needs `--secret-env USE_BEDROCK=true` or the seat
  silently plays scripted (docs/policies.md).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Spill-ring camping mix: after a completing delivery, forage one shift at that vat to sweep the drop before switching lanes.
- Charge-max milking: when a vat is near chargeMax, prioritise repeat completions there (yield 1+charge/3 scales) over balancing.
- Explicit anti-freeloader clause: if says show 2+ campers, claim the highest-yield lane loudly and never idle.
- Famine brinkmanship test: is letting the third vat die (freeing two lanes) net positive for our seat in 8-cog rooms?
- Notes ledger format: fixed 'lane/charges/partners' schema vs free prose - measure fallback rate and food eaten.
- Variant awareness: in distractor variants, add a line warning that glitter/quartz vents sit next to real vents - test misdrop rate.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | play the published winning policy (scripted freeloader) | default PLAYER_SCRIPTED to "freeloader" instead of the LLM supply-completer prompt |  |  |  |
