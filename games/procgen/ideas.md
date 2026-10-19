# Procgen — Skazochnik

Policy: **Skazochnik** (`skazochnik`) — the storyteller — endless generated tales.

Coworld: `cow_4479a226-d237-474a-8e64-118509030567` (coworld name `procgen`)

One cog, eight procedurally generated 15x9 tile levels in a row, four archetypes: a maze with gems behind a locked door, an open room of pellets patrolled by hunters, a stack of tiers over a lethal pit, and a wall of dirt hiding diamonds under falling boulders. Half the levels come from a seed table published in the repo; the other half are drawn out of two billion possibilities the moment the episode starts, and the cog is never told which is which. The score is the average return on the levels nobody has ever seen.

## Leagues

- `league_2b1f9007-0749-4e3c-a669-a630283894f1` — Procgen

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `pathfinder` — pathfinder: The careful baseline: it projects its whole six-frame plan through the resolver and drops it at the first frame that would kill the cog. The certification player, the per-turn fallback and the default for an unregistered seat. EXACTLY ONE bundled player is declared: every declared player must occupy a certification slot, and a one-seat fixture has exactly one. (run: `/bin/procgen-player`)

## Baseline

- Default and strongest example: `pathfinder` (PLAYER_SCRIPTED=pathfinder) — projects its whole six-frame plan through the resolver and drops it at the first lethal frame; also the certification player and per-turn fallback. `scavenger` exists in the image but is not declared in the manifest.
- Our policy: `skazochnik/` — defaults to scripted `pathfinder` (empty prompt so the server's `isLlm = prompt.len > 0` actually honours the baseline). NOTE the wire quirk: this game's registration is RAW JSON bytes on a binary websocket frame (no Sprite v1 0x81 framing, no 0x85 Ready), and the seat exits when a frame carries `"final"` — copied from the upstream `src/procgen_player.nim`. Empty `PLAYER_SCRIPTED` restores the operator prompt (per-archetype survival rules, collect-before-exit, approach-milli salvage). Env still overrides (`pathfinder` | `scavenger` | empty).
- Upload secret-envs: none for the pathfinder default. LLM override uses the game-pod `anthropic_api_key`; if a league LLM seat ever plays scripted anyway, retry with `--secret-env USE_BEDROCK=true`.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Prompt-embedded seen-level cheat sheet: study the 128 published training seeds (docs/training-seeds.md) for recurring generator motifs (gem placement biases, ladder layouts) and encode general heuristics — the seen half never scores, but motif priors transfer to unseen draws.
- Plan-length discipline sweep: force 6-move plans in maze (interrupt-free), cap at 3 in chaser/miner; measure planInterrupts and per-archetype return vs the uniform prompt.
- Exit-first switch point: try switching from collect to approach at 2 turns left instead of 3; approach pays 200 but a sixth gem pays 175 in a 4-gem level.
- Teach the dash escape explicitly: a worked example in the prompt ("hunter at Chebyshev 2 behind you, last_dir R, dash = 2 clear tiles → XRR") — the interrupt fires at distance 1, so pre-empting at 2 is the winning margin.
- Miner tunnel doctrine: always dig one lateral safety alcove before digging under any column that holds a boulder; measure crushed deaths vs the current side-approach rule.
- Notes format contract: fixed schema "next:<target> route:<moves> danger:<tile>" so each turn resumes the prior plan instead of re-deriving it (80 calls per episode make note continuity compound).

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Field built-in `pathfinder` instead of the LLM prompt. Dash 2026-09-01 (no field.md): 5/4, us #4 rating 894.89 mean 0.33. Leader is `procgen-example` (Andrew Brower, 1331.04, mean 0.69 over 12). Other LLM seats: cartographer 0.28, scrambler 0.30, richard 0.28. Example is the manifest's `PLAYER_SCRIPTED=pathfinder` image. Server sets `isLlm` from `prompt.len > 0` (src/procgen/server.nim), so our compiled defaultPrompt made every upload an LLM seat. Pathfinder is the sweep-tuned careful router (lookahead 6, digCost 1, detour 6; recorded ladder 7788 vs scavenger 7329 milli, +0.038, 16/16 unseen clears). Scripted/code A/Bs have won; prompt rewrites have lost. | default PLAYER_SCRIPTED to `pathfinder` and send an empty prompt while a baseline is named (env still overrides; empty PLAYER_SCRIPTED restores the operator prompt) | | | |
