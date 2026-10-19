# Rware Warehouse — Ovinnik

Policy: **Ovinnik** (`ovinnik`) — the barn spirit — warehouses.

Coworld: `cow_8d8e9a1e-02d8-48d2-9f57-8fc2cda72140` (coworld name `rware-warehouse`)

A port of semitable/robotic-warehouse (RWARE). Four robots share a small warehouse whose aisles are one cell wide: drive under a requested shelf, lift it, carry it to a workstation, then stow it again -- a loaded robot cannot pass under another standing shelf. Fully cooperative: the league reads the number of shelves the FLEET delivered, and the only way to lose it is to jam the aisles. Every seat is one robot driven by one JSON order every 20 ticks, and the only channel between the drivers is a 120-rune radio call.

## Leagues

- `league_05193716-123a-4941-a7c7-16a9643ebe37` — Rware-Warehouse

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `courteous` — rware-warehouse-courteous: The published scripted default and the server-side fallback: it yields when it and a lower-slot robot have both been blocked, stows clear of the workstation queue lane, delivers to the less crowded workstation, and leaves a shelf another robot is already closer to. (run: `/bin/rware-warehouse-player`)
- `shuttle` — rware-warehouse-shuttle: Pure greed, no jam handling: stow a delivered shelf, deliver a requested one to the nearer workstation, otherwise fetch the requested shelf with the shortest path. A real opponent to jam against, and the control that answers whether the LLM actually coordinated. (run: `/bin/rware-warehouse-player`)

## Baseline

Default example: `courteous` (yields on mutual blocks, stows clear of
the queue lane, balances stations — the published default and the
server-side fallback); `shuttle` is pure greed with no jam handling.
Despite docs/porting.md, this is a prompt seat, not a command player:
the player binary is a thin Sprite v1 registrar and all decisions are
made inside the game server (docs/PROTOCOL.md). Our `ovinnik` is that
registrar rewritten in Nim (0x81 chat registration with
{"policy","prompt","scripted"} — no "type" field — re-sent ~10 s).
**Default is scripted `courteous`** (the published example and league
leader `rware-warehouse-example`): yields on mutual blocks with a
lower-slot partner, stows clear of the queue lane, balances stations,
penalises a closer robot's shelf. PLAYER_PROMPT / PLAYER_SCRIPTED
(shuttle | courteous) overrides; empty PLAYER_SCRIPTED fields the
operator prompt (radio claims, alias-ordered yield). LLM seats need
USE_BEDROCK=true at upload.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Benchmark ovinnik+3 courteous vs 4 courteous on hosted XP: does the radio protocol raise teamDelivered at all, or is courteous already the ceiling?
- Yield-rule A/B: loaded-robot-has-right-of-way vs courteous's lower-slot rule — mixed tables may deadlock when the two conventions disagree; measure jamTicks.
- Station assignment: try a static split by alias (Alpha/Bravo → W1, Charlie/Delta → W2) instead of radio-negotiated — fewer words, no collisions.
- Stow placement: prompt a preferred stow ring (outermost storage columns) so the centre lanes stay permanently clear; compare longestJamTicks.
- Claim horizon: claim TWO shelves ahead ("S12 then S19") so others plan around your next trip, not just this one.
- Fetch tie-break: nearest-shelf vs "nearest shelf whose route avoids the queue lane" — routing cost may beat distance in the one-wide aisles.
- Watch fallbackTurns: if parse failures show up, shorten the prompt's decision list to the five verbs and one jam rule.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| - | fleet/triage candidate v2 | see git history | triage batch | paired vs champion | REVERT: 1403.5 flat |
| 1 | Field built-in `courteous` instead of the LLM prompt. Leader is `rware-warehouse-example` (Andrew Brower, rating 1152.95, wr 83%, mean 1239.6). League is mixed 4-seat tables ranked by score=100*teamDelivered+delivered[s]; a jam zeros the fleet. Example beats ovinnik 9-1-5 (77%) and auction-stow 11-2-2 (80%). Courteous is the published default, the server fallback, and the yield/stow/station policy sweep-tuned to yieldAfter=4. Our prompt uses a different yield convention (loaded right-of-way + later alias, wait until blocked_ticks>=8) which deadlocks against courteous on mixed tables and waits until a jam is already declared. | default PLAYER_SCRIPTED to `courteous` in ovinnik.nim (env still overrides) | | | |
