# Infinite Blocks — Svarog

Policy: **Svarog** (`svarog`) — the smith god who forges the world.

Coworld: `cow_dfab101b-4c05-461f-8f44-663f2cf2a525` (coworld name `infinite_blocks`)

A multiplayer BitWorld falling-blocks game where players stack pieces, clear lines, and compete for score on one shared board.

## Leagues

- `league_ab1cc8ce-365c-488b-84c3-7ebc5156b71d` — Infinite Blocks

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `stacker` — Stacker: Sprite-protocol Infinite Blocks bot that searches for low, flat landing spots and scores by causing line clears. (run: `/bin/stacker`)

## Local baseline

~/p/coworld-infinite-blocks — hosted hourly league work; stacker is the platform base.

## Baseline

- Default and strongest example is `stacker` (the only example player); it is
  also the platform base policy in our hosted hourly league, and we tuned it
  extensively in ~/p/coworld-infinite-blocks (hosted paired A/Bs, see that
  repo's README "What has actually been measured").
- Svarog IS that tuned stacker source, copied to `svarog/svarog.nim` and
  trimmed: the `-d:gui` diagnostic viewer is stripped, the tiny
  `bitworld/spriteprotocol` slice it used (input-mask bits, blobFromBytes) is
  inlined, and supersnappy 2.1.4 plus whisky are vendored beside it (the
  Dockerfile needs no clones). Command player over
  two sprite_v1 websockets (`/player` viewport + `/global` map): finds its
  own color, infers the active piece from connected components, scores every
  reachable placement (holes, bumpiness, height, lane anchoring, clear runs,
  one-piece lookahead from the preview), then holds a button mask.
- Compile-time feature flags default to the best-measured configuration
  (adaptive lane, anchor lane, lookahead ON; unstick/commit/valueScoring/
  blindWiggle/stickyTarget/ownerValue/travelDrop/cascade OFF because hosted
  A/Bs scored them at or under baseline). `-d:tunable` exposes the lane
  weights as env vars for sweeps.
- Upload: plain command player, `--run /bin/policy_player`, no secret envs
  (no USE_BEDROCK — there is no LLM seat in this game).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Re-test `W_ROW_COMPLETE` high (the offline rig said 400000 vs shipped
  24000, hosted pooled -46.3 disagreed — retry now that the field changed).
- `-d:unstick` A/B: the stuck-piece sideways-burst breaker was never proven
  hosted; deadlocks against other bots' active pieces cost whole games.
- `-d:ownerValue` A/B: price multi-owner clear runs (`OwnerValueBonus`) —
  clears pay length x distinct owners, and the lane follows the crowd.
- Deeper lookahead: raise `W_LOOKAHEAD_WIDTH` past 6 and score the reply
  with the real lane scorer instead of the binary clear-found bonus.
- `-d:actOnQuietTick` A/B: keep issuing masks on quiet receive ticks instead
  of skipping the decision (cheap latency win if state staleness is mild).
- `-d:chatDiag` probe round: use replay chat telemetry to confirm global-map
  scale and decision latency inside league containers before other A/Bs.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
