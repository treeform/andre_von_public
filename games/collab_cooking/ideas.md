# Collab Cooking — Kolobok

Policy: **Kolobok** (`kolobok`) — born in the kitchen.

Coworld: `cow_19938c0f-195a-45f8-95da-761f0ffe04cb` (coworld name `collab_cooking`)

Four cogs share one kitchen for 900 ticks. Tickets arrive on an order board and expire; a dish is a chain of single-item errands and a cog can carry exactly one thing. Team score = dishes served. Eight Melting Pot kitchens, each isolating one coordination problem.

## Leagues

- `league_592e6ed0-3f01-4084-bb90-75ace0db0063` — Collab Cooking

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `collab-prompt` — Reference prompt: The reference prompt policy: an LLM shift order every 50 ticks. (run: `/bin/collab-cooking-player`)
- `brigade` — Brigade: prep / cook / server / all-rounder roles, the shipped scripted brain. (run: `/bin/collab-cooking-player`)
- `passer` — Passer: never crosses the midline; always stages on the pass counter. (run: `/bin/collab-cooking-player`)
- `courier` — Courier: every seat serves; the greedy-service control. (run: `/bin/collab-cooking-player`)

## Baseline

NOT a thin prompt seat: the player container must send one action every tick with `request_id: "step-<t>"` — even prompt seats run a local executor (the game only sends a `plan` shift order every 50 ticks). **Default is `PLAYER_SCRIPTED=runner`** (every seat all-rounder; empty prompt path so we register `kind: scripted` and the game never sends LLM plans). Empty `PLAYER_SCRIPTED` restores the operator prompt. Env still overrides (`brigade` | `runner` | `passer` | `courier` | empty). `brigade` remains the fallback for a failed plan turn on a prompt seat. Kolobok (`kolobok/kolobok.nim` + `kolobok_brain.nim`) is a full Nim port of the reference brain: mettagrid token decoding (nibble-packed locations, `lp:`/`inv:`/`tag` features from the `policy_env` tables), the sparse spawn-relative entity map with the elliptical view mask, the A* navigator with stuck-breaking, the brigade role branches, the stall/unstick rules, and the plan executor (`station`/`recipe`/`zone`/`handoff`; alias-`handoff` and `yield_to` are inert exactly as in the reference, which never learns ally positions). Upload note: default is scripted, so no Bedrock flag is required. LLM override needs `--secret-env USE_BEDROCK=true`.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Verify the port on the hosted ladder first: one XP request vs three brigade seats on `cramped` should score close to all-brigade; any large gap means a token-decoding or navigation bug, not a strategy problem.
- Prompt zone discipline on `forced`: the whole game is the divider — try a harder prompt line assigning left = veg+meat+chop+sink, right = pot+fryer+pass by alias half, and measure dishes vs the current softer wording.
- Burn guard: the executor could refuse a plan `station` that walks away from a pot with `pot_soup_ready` while holding a clean plate (client-side veto, one line in stepBrain); measure burned-pot events in replays.
- Salad throughput: salad needs no cooking and every 5-ticket cycle has 2 salads — test a prompt that keeps one cog permanently on the plate->board salad loop.
- Ticket-expiry awareness: tickets die 50 ticks after arrival; ask the planner to prefer the OLDEST live ticket's recipe (visible ticket index order) instead of the deepest queue.
- Wash cadence: plates are the loop bottleneck at 3 sink uses per plate; test `station: sink` standing orders for the all-rounder between rushes vs letting brigade's dirty-plate rule handle it.
- Port the reference `note_allies` gap: if a future game build publishes ally positions to players, wire them into `yield_to`/alias-handoff (already implemented but inert).

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Field built-in `runner` instead of the LLM prompt. Dash 2026-08-27 field.md: 4 rated, us later #6/6 rating 883.3. Leader is `co-gas-collab-cooking-runner-relhalpha` (relh, 1131.2, wr 0.46); richard also fields runner (1020.9, wr 0.32). Prompt seats (linecook/expo, daveey) sit at wr 0.13 / 0.00. Score is `dishes + 0.01 * delivered[i]`; brigade pins slot 0/1 to prep/cook so they never collect the epsilon and cannot cover a bad partner. Runner is every seat all-rounder (nearest useful job). Scripted seats get no `plan` turns, so an LLM cannot walk us off a ready cooker. Scripted/code A/Bs have won; prompt rewrites have lost. | default PLAYER_SCRIPTED to `runner` and register kind=scripted while a baseline is named (env still overrides; empty PLAYER_SCRIPTED restores the operator prompt) | | | |
