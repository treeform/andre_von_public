# Sumo Traffic Signals — Svetofor

Policy: **Svetofor** (`svetofor`) — the traffic light spirit.

Coworld: `cow_cb7e4236-ebda-400b-bba8-7c673b91dd15` (coworld name `sumo-traffic-signals`)

Sixteen signalised intersections on a 4x4 city grid. Four controllers own a quadrant each and decide, every eight simulated seconds, what their four signals do next: hold, switch, switch after a delay (which is how you build a green wave), or hand the intersection to a greedy actuator. Cars enter from sixteen edge gates and drive fixed shortest routes over single-lane approaches made of cells, so a left-turner at a stop line blocks the whole avenue and a green into a full block moves nobody. The only number the league reads is how many cars got all the way out of the city: your green is your neighbour's queue.

## Leagues

- `league_0a4b0ef0-557c-4c54-b439-788cede68a73` — Sumo Traffic Signals

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `greedy` — Greedy actuator: The standard longest-queue actuated controller: every turn it serves whichever phase has the longest movable queue, and it never looks at whether the block it is discharging into has room. Local greed, shipped as the thing to beat. (run: `/bin/sumo-traffic-signals-player`)
- `fixedcycle` — Fixed-time plan: The classic fixed-time plan: one phase per turn from NSG, EWG, NSL, EWL, identical at all four of its intersections and therefore with zero offset between them. No sensing, no coordination — what a city looks like before anybody tunes it. (run: `/bin/sumo-traffic-signals-player`)

## Baseline

Two bundled examples: `greedy` (longest-movable-queue actuator, also the
server-side fallback and what an unregistered seat plays — it discharges
into full links and exports congestion, "the thing to beat") and
`fixedcycle` (one phase per turn from NSG/EWG/NSL/EWL, zero offsets, the
did-you-actually-coordinate control). Certification runs two of each.
Our policy **Svetofor** (`svetofor/svetofor.nim`) is a Nim prompt seat
over the Sprite v1 BINARY protocol: one 0x81 chat packet carrying
`{"type":"register","prompt","policy","scripted"}`, re-sent through the
first ~10 s of received frames, then a 0x85 Ready byte per frame —
docs/PROTOCOL.md explicitly blesses Ready for this game (seats send no
inputs; every variant is fastMode). The prompt is a priority list:
never green into a full exit link, gate upstream feeders on spillback,
serve blocked left-turners past 10 blocked_ticks, build green waves with
`wave` delays timed by travel minus the 2-tick all-red (4 EW, 2 NS) and
inbound nearest_ticks, coordinate offsets over the radio every turn (and honour
neighbours' announced waves), default `auto` off-wave, react to
`deferred`/`repaired` order results, and flush instead of store from
turn 26. `PLAYER_PROMPT` overrides, `PLAYER_SCRIPTED=greedy|fixedcycle`
fields a baseline. NO upload secret-envs — docs/PROTOCOL.md says it
outright: the anthropic_api_key secret is injected into the GAME pod and
no USE_BEDROCK flag is needed on a policy.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Quantify rule 1: "full" is binary in the view but occupancy/capacity
  is not — try refusing greens at occupancy >= capacity - 1 (a green
  discharges up to 6 cars into a 6-cell block).
- Radio grammar: fix a machine-parsable say format ("C: EWG C1+0 C2+3
  C3+6") so LLM neighbours can adopt offsets verbatim; measure waves
  count in network_status with and without.
- The `your_wait_ticks` tiebreak: the score is city throughput, but
  seatWaitTicks is reported — check whether the league reads it; if
  not, stop trading own-quadrant delay for network exits so eagerly.
- Demand-aware opening: turns 1-4 queues are short; force `auto`
  everywhere before any wave building and compare against
  wave-from-turn-1.
- Anti-greedy defense: when a neighbouring quadrant (greedy filler)
  keeps flooding our shared avenue, gate our upstream signal into it at
  max_red-safe holds and route our own platoons on the cross street.
- Try `fixedcycle` seeding in the prompt: open with two full NSG/EWG
  alternations at zero offset to meter inflow evenly, then switch to
  wave logic once detectors show direction of dominant demand.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Wave delay ignored 2-tick all-red clearance, so `wave delay 6` never greens this 8-tick turn and the platoon stops (breaks clean crossings / waves). Scoring is city exits; waves are a means. field.md missing; we are #2/5 at 1033.3 — leader likely times offsets so the platoon actually hits green. | Rule 4 only: EW delay 6→4, NS delay 4→2 (delay = travel − clearance); nearest_ticks − 2, clamp 0..6. | | | |
