# Snake Royale — Zmeya

Policy: **Zmeya** (`zmeya`) — the snake.

Coworld: `cow_5063454a-3a43-46c6-8df5-ea0c1f335d78` (coworld name `snake-royale`)

Four snakes, one small grid, simultaneous moves. Eat to grow, never hit anything, and outlive the other three. One engine, three rule modules: the merged Snake Royale board, the Kaggle Hungry Geese torus, and Tron light cycles.

## Leagues

- `league_9f435441-c018-419e-b8af-124d7a488081` — Snake Royale

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `coil` — coil: The survival heuristic: space first, food only when hungry or free. The certification player, the per-turn fallback and the default for an unregistered seat. (run: `/bin/snake-royale-player`)
- `forager` — forager: Visibly greedier: it beelines for food and accepts tighter space, so it grows faster and traps itself more. The thing a champion should be able to beat. (run: `/bin/snake-royale-player`)

## Baseline

`coil` is the published default and the per-turn fallback (space first, food
only when hungry or free); `forager` is the deliberately-beatable greedy one.
The seat is a thin registrar: one binary JSON `register` blob, then listen.
The GAME server decides every turn. `isLlm = prompt.len > 0`, so a non-empty
prompt ignores any named baseline.

**Zmeya** (`zmeya/`) defaults to scripted `coil` (empty prompt) — the same
policy as league-leading `snake-royale-example`. Coil's swept knobs
(spaceWeight 100, spaceCap 2×length, hungerThreshold 12, killBonus 120)
beat forager by +0.1805 on the mirrored ladder and beat every active
league seat. Empty `PLAYER_SCRIPTED` restores the operator prompt.

Upload secret-envs: none for the coil default. LLM override uses the
game-pod `anthropic_api_key`; if a league LLM seat ever plays scripted
anyway, retry with `--secret-env USE_BEDROCK=true`.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Free-kill emphasis: the alliance audit shows declined kills; a prompt line
  that always takes a `head_risk: win` cell when free_space >= own length
  may convert those into removed rivals.
- Anti-forager opening: the greedy baseline beelines food — a prompt rule to
  shadow the nearest food WITHOUT taking it, forcing the head-on we win.
- say-channel games: claim the lane we are NOT taking when two rivals are
  near it, and test whether the LLM opponents actually read `said`.
- Health ledger in notes: track exact health vs distance-to-nearest-food and
  eat at the last safe turn instead of the fixed under-12 trigger.
- Endgame region control: an explicit two-snakes-left protocol — wall off
  the larger region and never cross into the rival's half.
- Turn-1 book: all four directions are legal on turn 1; open toward centre
  away from the nearest rival anchor (anchors are fixed, derivable).

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | default to swept coil (league leader snake-royale-example, 0 LLM, mean +0.50, 18-3 vs our prompt; our LLM prompt is last at 816.5 / mean −0.43) | PLAYER_SCRIPTED defaults to coil and prompt is emptied so server isLlm=false (prompt.len>0 would ignore the baseline) |  |  |  |
