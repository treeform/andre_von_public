# Crewrift — Kikimora

Policy: **Kikimora** (`kikimora`) — the hidden saboteur in the house.

Coworld: `cow_074b816f-2807-4e99-acf0-645359b800db` (coworld name `crewrift`)

One Crewrift runtime catalog for the separate Classic and Prime leagues, plus Prime training scenarios.

## Leagues

- `league_a12f5172-0907-4d04-8bcb-ca02f5360e3a` — Crewrift Prime
- `league_605ff338-0a2e-4e62-aeda-559df9a9198f` — Crewrift

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `notsus` — notsus: Sprite-protocol Crewrift bot used for local smoke episodes. (run: `/bin/notsus --exit-on-disconnect --exit-on-game-over`)

## Local baseline

~/p/coworld-crewrift — notsus example bots; our local quick_run harness knowledge.

## Baseline

- Default (and only) example in the package: `notsus` — the full Nim
  sprite-protocol bot from ~/p/coworld-crewrift/players/notsus, run as
  `/bin/notsus --exit-on-disconnect --exit-on-game-over`.
- Our policy: **command player**, the proven **truecrew** bot vendored
  wholesale (github.com/treeform/truecrew, commit
  73406ad0ac49c95ca5457080da71d8e2518d002a — working-tree HEAD, the
  lineage submitted to the league as `truecrew:v24`, ranked **#6**).
  `kikimora.nim` is truecrew.nim renamed (one-line staticRead path
  adaptation), plus `truecrew/{navigation,pathing,protocols}.nim` and
  `prompt.md`. It compiles against the real crewrift sim
  (Metta-AI/coworld-crewrift @ 8fa2822, notsus-optimizer branch, cloned
  in the Docker build) with `-d:botHeadless`: sim-backed frame fitting
  and patch matching, JPS+ pathing with lane damping, the sus/trust
  engine, real vote targeting, and Bedrock voting chat with guardrails.
  The earlier clean-room port (old kikimora.nim + sprite_wire.nim) was
  much weaker and has been deleted.
- Upload secret-envs: none required to play. Optional
  `BEDROCK_KEY`/`AWS_BEARER_TOKEN_BEDROCK` secret-env enables the voting
  LLM chat; without it the bot plays silently with scripted votes.
- Deps are pinned by `kikimora/nimby.lock` (copy of coworld-crewrift's
  lock: bitworld a6aa1da, pixie, pathy, whisky, ...).
- Local runs: 8 notsus bots need `--slots` (see memory); XP requests only
  for scoring.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

(the pre-truecrew backlog — vote targeting, momentum control, meeting
chat, vent awareness, task routing — is already implemented in the
vendored bot; fresh ideas below)

- Sus-score tuning: the sus/button-reset thresholds were last tuned in
  truecrew commit f4f7a5c; sweep SusVoteMinScore up/down one notch and
  XP-test against the current league field.
- Bedrock voting chat on: upload a variant with the BEDROCK_KEY
  secret-env and A/B it against the silent build — does talking move
  vote outcomes enough to pay for the latency?
- Prime-league map audit: the bot pins crewrift @ 8fa2822; check whether
  Prime scenarios have drifted (new maps/tasks) and rebase the crewrift
  pin if frame fitting starts missing.
- Imposter kill-window model: track per-opponent camera adjacency over
  time and only kill when the projected witness count is zero for the
  next N ticks, not just the current frame.
- Crew buddy bias: weight the JPS lane-damped router toward paths shared
  with one trusted crewmate to build vouch pairs for votes.
- Early-game task tour: seed the task order with a precomputed
  low-travel tour per spawn room instead of nearest-next for the first
  three tasks.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | silent meetings time out instead of voting; crew also ejects randomly with no evidence | bypass the Bedrock chat gate when no token so scripted votes fire; crewmates skip unless sus >= SusVoteMinScore (imposters still vote/bandwagon) | | | |
