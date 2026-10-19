# Factorio — Danila Master

Policy: **Danila Master** (`danila`) — Bazhov's master craftsman.

Coworld: `cow_dc2d9596-dc2d-4251-a841-c0afe81968e8` (coworld name `factorio`)

The Factorio Learning Environment (FLE 0.3.0, Factorio 1.1.110) as a Coworld: each seat gets its own headless Factorio server on the FLE lab map and plays a fixed number of steps, each step a Python program written against the FLE agent API (place_entity, connect_entities, nearest, craft_item, sleep, ...). Open play scores each seat by FLE production score; throughput variants score by achieved items/minute of a target item. Seats never share a map, so scores are absolute and comparable across episodes. Replays record every program, its output, and an entity snapshot per step, rendered by a static wasm viewer.

## Leagues

- `league_09df6929-74d3-45ae-8857-4bb69d2880d1` — Factorio

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `burner` — burner baseline: Scripted baseline: burner mining drills on the iron and coal patches feeding stone furnaces, refuelled every few steps. Image placeholder is replaced at deploy time. (run: `python -m players.burner_player`)
- `handcraft` — handcraft baseline: Scripted baseline: hand-mines ore and smelts it in hand-placed stone furnaces; no automation. (run: `python -m players.handcraft_player`)
- `idle` — idle baseline: Scripted baseline: replies with a no-op program every step (score floor). (run: `python -m players.idle_player`)

## Baseline

Command player (`cogame.factorio.v1`): one Python program per step against the seat's own FLE server. The default and strongest scripted example is `burner` (`python -m players.burner_player`, source Metta-AI/cogame-factorio `players/burner_player.py`); `handcraft` and `idle` are weaker controls. `danila/danila.nim` is a faithful Nim port of the burner baseline: phased build-out (5 iron drill+furnace pairs, 3 copper pairs, coal and stone drills into chests) gated on what the observation shows standing, phase abandonment when a placement step adds no drills, then per-step maintenance (extract plates, restock coal from chests under 60, refuel anything under 6 coal, craft gear wheels from 20+ iron plates, sleep 30). Program templates render byte-identical Python to the reference; starting inventory read from `welcome.episode.starting_inventory`, never hardcoded. Bounded reconnect loop (the server re-sends welcome + the current observation). No LLM, so no upload secret-envs required.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Score-aware sleep: the maintain step sleeps 30 s of game time; poll `flows.output` and cut the sleep short (smaller `sleep()` plus more maintenance passes) when furnaces show `no_fuel`/`full_output` status, which the observation already carries.
- Electric ramp: after the burner base runs, spend mid-episode steps on offshore pump + boiler + steam engine and electric drills — the FLE production-score curve strongly rewards graduating off burners.
- Automate gears into science: hand-crafting gear wheels stops at gears; craft automation science packs (gears + copper plates are already in inventory) and, if a lab is placeable, research for the score multiplier.
- Use `last_program.output` diagnostics: parse the printed `placement N failed:` lines and re-aim the next placement program (shift row by ±2 tiles) instead of blindly abandoning the phase after one empty attempt.
- Throughput-task specialization: `welcome.task.key` names throughput variants; when the task is `iron_plate_throughput`-style, skip copper/stone phases entirely and put every drill and furnace on the target item's chain.
- Second furnace row: drills mine faster than one furnace smelts; place a second furnace beside each iron drill fed by hand-moved ore during maintenance steps, trading walk time for smelt throughput.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Wall-clock sleep. Open-play score is FLE production score (value of net items produced over the episode); production only happens while game time passes. Maintain slept a hardcoded 30 game s (~3 real s at speed 10), leaving most of the 45 s program timeout and 3000 s wall-clock unused. Leader policies (`factorio-foundry`) outscore the burner baseline by running the factory longer/faster, not by a different win condition. | Maintain `sleep` = (program_timeout−15)×game_speed from welcome (~330 game s); placement sleep half of that. Extract/refuel/craft raised so stone-furnace output (stack 100) and burner fuel (~13 coal / 330 s at 150 kW) last the sleep instead of jamming/`no_fuel`. Gear craft cap 25→200 so the extra plates convert. | | | |
