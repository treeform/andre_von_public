# Polis — Marfa Posadnitsa

Policy: **Marfa Posadnitsa** (`marfa`) — Novgorod's republic stateswoman.

Coworld: `cow_dd543363-01e2-42dd-afe7-b87ed5b8f3c2` (coworld name `polis`)

Polis — Nomic with an economy: LLM cogs mine resources, build & align Commons datacenters onto research projects, trade shares on a bonding curve, and propose & vote on laws that reshape the rules. Most Hearts (from project payouts + per-turn goals) after the horizon wins.

## Leagues

- `league_69189dd1-61c5-4ade-a554-39416eef19de` — Polis

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `polis-baseline` — Polis Baseline: Deterministic no-LLM baseline (parties every turn: no actions, proposes nothing, abstains). Certifies the contract offline. (run: `node dist-server/game/baseline-player.js`)

## Baseline

The only example is `polis-baseline`, the deterministic no-LLM contract
certifier: party in plan (no actions), pass in amend (no amendments),
abstain in vote — `baselineForPhase` in the engine, and the literal floor
(illegal/late replies are replaced with it server-side). `marfa` used to
be a faithful Nim rewrite of that floor; it now plays a real scripted
policy on the same `cogweb.player.v1` envelope (`{type, id, decision,
messages: []}` echoing the observation id):

- **plan** — greedy self-interest from the redacted view: mine / sell /
  craft Nanites, align (and steal) Commons datacenters onto the project
  that maximizes our expected Hearts, buy bonding-curve shares toward
  majority, and chase `you.goals` that pay +1♥ this turn.
- **amend** — bid-0 addition that names us as the Hearts beneficiary
  (the scripted Governor currently no-ops, but passage still scores
  `amendmentPassedThisTurn` and is the legal value-shift).
- **vote** — yes iff a parse of additions/removals says the amendment
  raises our Hearts, otherwise no (computed from the observation, not
  vibes; never abstain on a scored ballot).
- **host re-request** (`reason` set) — always-legal floor fallback.

No LLM, so upload needs no secret-envs; a future Bedrock-driven version
must use `--secret-env USE_BEDROCK=true` and the sidecar endpoint
(`AWS_ENDPOINT_URL_BEDROCK_RUNTIME`, InvokeModel not Converse). Protocol
confidence is high: the zod envelope
(`packages/cogweb/packages/coworld/src/protocol.ts`) and the polis
player-protocol doc are both local in the metta repo.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Tighter goal chaser: simulate the planned slate against every
  `you.goals` check (resourceGte / alignsThisTurn / industrialist /
  saboteur / founder) and insert the cheapest missing action before
  fillers — today's planner covers them opportunistically, not as a
  scored set cover.
- Late-project staking: `buyStake` the highest progress/bar project in
  the last 3 turns even when we already have majority elsewhere (horizon
  liquidation is un-penalized pro-rata); sell stakes in 0-progress
  projects we cannot fuel.
- Fuel the tank: when commons Silicon/Germanium cannot feed aligned
  datacenters, `sell` Si/Ge into the Commons account before aligning
  more — extra aligns are idle if the tank is dry.
- Bid just above `minProposalBid` when a rival is also drafting, so our
  self-dealing amendment sorts first on the floor (ties break by cog
  order; we don't observe min bid, so infer from rejected drafts).
- LLM seat: drive plan/amend/vote with a Bedrock prompt (the game is built
  for LLM cogs) — needs the sidecar contract above plus robust JSON-only
  decision parsing.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | replace floor baseline with real scripted seat | greedy plan + beneficiary amendments + evidence votes | xreq_0b18599f | top-3 field, 12 paired eps | KEEP: v2 35.50 vs v1 1.75, 12/12 wins, t=6.16; promoted |
| 1 | leave the floor | replace party/pass/abstain with observation-computed self-interest: plan mines/aligns/stakes, bid-0 self-dealing amendments, vote yes only when Hearts delta > 0; `reason` falls back to the engine floor | — | — | pending |
