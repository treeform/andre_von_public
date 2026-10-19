# Hide And Seek — Pryatki

Policy: **Pryatki** (`pryatki`) — the game itself — hide and seek.

Coworld: `cow_b6316da8-ebfc-464d-9383-44e5323c435c` (coworld name `hide-and-seek`)

Three cogs hide, three cogs seek, nobody has a weapon. Fifteen seconds to drag crates, wall a doorway and lock it; thirty seconds of torch cones looking for you; then the trios swap sides and play the same room again.

## Leagues

- `league_7931991b-df9e-4248-98ca-c613dac7137d` — Hide and Seek

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `burrow` — burrow: The published scripted baseline: walls a doorway with the nearest panel or crate, LOCKS what it placed, drags the ramps to a far corner and locks them there, then hides in a pocket facing the door. As a seeker it sweeps the patrol ring, shoves unlocked furniture aside and vaults a locked wall. It is also the server-side fallback when an LLM seat fails twice. (run: `/bin/hide-and-seek-player`)
- `scatter` — scatter: The weaker baseline, different in SHAPE rather than in degree: it never touches the furniture. As a hider it alternates between the two pockets furthest from the seeker pads and runs when a seeker is known within 180 px; as a seeker it walks a third of the patrol ring and chases what it sees. (run: `/bin/hide-and-seek-player`)

## Baseline

- Default and strongest example: `burrow` (PLAYER_SCRIPTED=burrow) — walls a doorway, locks what it placed, drags the ramps away and locks them, hides facing the door; sweeps/shoves/vaults as a seeker. Also the server-side fallback after two failed LLM calls. `scatter` is deliberately weaker (never touches furniture).
- Our policy: `pryatki/` — a thin Sprite v1 prompt seat (0x81 register chat frame, 0x85 Ready per frame). The crafted prompt IS the strategy, split by role: hiders run a three-way job split (wall + lock, ramp exile, second brick) with lock-immediately discipline and a stand-still sealed fort; seekers run a three-way sweep split, shove unlocked furniture, vault via ramps, and park a cone permanently on any found hider (exposure pays per tick).
- Upload secret-envs: none — the platform injects `anthropic_api_key` into the GAME pod and every order decision happens server-side. If a league seat ever plays scripted anyway, retry with `--secret-env USE_BEDROCK=true`.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Prep-turn timing budget: 4 turns is tight — try assigning both panel AND its lock to the same seat in one turn pair (push turn 1-2, lock turn 2-3) and measure sealedTicks at release vs the current split.
- Ramp exile vs ramp hoard: instead of the far corner, drag both ramps INSIDE the fort before sealing — seekers then have zero vault routes; risk is fort-space congestion blocking the last crate.
- Seeker anti-fort opening: skip the sweep entirely when a locked wall is found in the first two hunt turns — all three converge, one shoves every unlocked object nearby, two hunt the inevitable gap angle.
- Found-hider handoff: when the parked watcher's target is sealed behind glass-tight geometry, test whether chase (which re-noses into the pocket) holds the pay-tick more reliably than watch through the gap.
- Shout bait: a hider `say` is audible within 144 px — as a seeker, prompt to note heard shout positions as target regions; as a hider, forbid say entirely (currently prompted) and verify via replay shouts counter that we never leak.
- Two-pocket split test: all-in-one-fort vs 2+1 (two sealed, one scatter-runner drawing cones); scoring counts any-seen ticks, so the runner must actually be unseen to help — measure seatSeenTicks per hider.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| - | fleet/triage candidate v2 | see git history | triage batch | paired vs champion | REVERT: 0.06->-0.06 t=-0.36 |
| 1 | found-hider hold uses chase not watch | operator prompt SEEKING #3: `watch` parks a +/-32 brad sweep (35° half-cone loses a still target); `chase` aims at last-known every tick (control.nim, same as burrow) |  |  |  |
