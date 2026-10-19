# Crafter — Levsha

Policy: **Levsha** (`levsha`) — the master craftsman who shod a flea.

Coworld: `cow_6b6acab7-d2c6-4f26-b983-14a6bb9a3179` (coworld name `crafter`)

One cog alone in a 64x64 procedurally generated wilderness it can see nine cells of. Chop wood, place a crafting table, make a pickaxe, mine stone, build a furnace, smelt iron and cut a diamond out of the mountain - while keeping health, food, drink and energy off zero and surviving the zombies that come out at night. The score is how many of Crafter's 22 achievements it unlocks before it dies. A policy is just a prompt.

## Leagues

- `league_791e396c-32b3-47f1-bd94-23e276f6b6c5` — Crafter

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `forager` — forager: The published scripted baseline: a deterministic priority ladder that drinks, eats, shelters at night and climbs the tech tree. It is also the server-side fallback whenever a seat's LLM call fails twice, so every turn always has a legal plan. (run: `/bin/crafter-player`)

## Baseline

The only published example is `forager`, a deterministic priority ladder
(drink, eat, shelter at night, climb the tech tree) — the same thin image
as the game, selected with `PLAYER_SCRIPTED=forager`, and also the
server-side fallback after two failed LLM calls (a weaker `wanderer` also
exists in the image). The seat is a **prompt seat**: the player container
registers one Sprite v1 binary chat blob (`{"type":"register", "prompt",
"policy", "scripted"}`, re-sent for the first ~10 s, Ready 0x85 acks) and
the game server sends the prompt plus the 9x9 view to Claude every turn.

**Levsha** (`levsha/`) embeds a crafted operator prompt: a ten-step
achievement speedrun order (wood -> table -> wood tools -> sapling planted
EARLY -> drink -> cow -> stone tools -> furnace beside table -> coal/iron
-> iron gear -> diamond -> zombie/skeleton kills), night shelter and
wake_up ritual, place_stone lava crossing, vitals thresholds, and
notes-as-memory with base coordinates. Upload secret-envs: **none
needed** — the `anthropic_api_key` coworld secret lives in the game pod;
no USE_BEDROCK, prompt compiled in (PLAYER_PROMPT overrides).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Quantify the sapling grind: ~10 `do`-on-grass for one sapling costs half
  a turn — say exactly when to grind it (while walking between jobs, never
  as a dedicated trip) and check eat_plant actually lands before the cap.
- The furnace-beside-table base is load-bearing: add an explicit "build
  the base at the stone/grass boundary nearest water" site-selection rule
  to cut the walking tax between wood, stone and drink.
- defeat_zombie is free the first night IF armed: try moving
  make_wood_sword before make_wood_pickaxe and holding the door of a
  stone nook at dusk instead of hiding.
- Skeleton hunt: prompt a dedicated cave trip after iron gear with
  place_stone used to plug arrow lines; measure death rate vs achievement
  gain.
- Endgame idle risk: after 20-21 achievements the model may wander into
  night fights it does not need — add an explicit "when nothing is locked
  but diamond, mine and then hole up until the cap" closing rule.
- Try a leaner prompt that trusts `nearest`/`landmarks` instead of the
  full opening script; the priority ladder may survive compression and
  free attention for threat handling.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| - | fleet/triage candidate v3 | see git history | triage batch | paired vs champion | REVERT: arms 8.0 vs 7.2 ach |
| 1 | achievement-max prompt v2 | ladder rewrite w/ gates | xreq_658+426 | solo arms, 8 eps each | REVERT: v2 5.8 vs v1 8.4 achievements (t=-1.54); v1 ladder stays |
| 2 | 1-hit ore mining (prompt cargo-culted original Crafter hardness) | stone/coal/iron/diamond: 1 do then walkable `=` path; bank 4 stone via do-step-do, not do n=4 on one cell; trees stay infinite | | | | |
