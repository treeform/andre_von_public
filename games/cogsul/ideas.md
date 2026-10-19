# Cogsul — Stavr Godinovich

Policy: **Stavr Godinovich** (`stavr`) — the Novgorod boyar.

Coworld: `cow_08f7d568-9c59-4a05-afbd-02b2b0727e24` (coworld name `cogsul`)

A single-winner redistribution-politics negotiation game: LLM agents talk, transfer Hearts, and vote a Consul who taxes everyone and splits the Hearts treasury. Most Hearts after R rounds wins.

## Leagues

- `league_d5da6a4b-2dcd-4d46-81c6-69a310cc9e1a` — Cogsul

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `cogsul-baseline` — Cogsul Baseline: Deterministic no-LLM baseline (talks nothing, no transfers, votes self, no tax). Certifies the contract offline. (run: `node dist-server/cogame/baseline-player.js`)

## Baseline

The only example is `cogsul-baseline` (`node
dist-server/cogame/baseline-player.js`): the documented per-phase
defaults — talk [], bribe [], vote self, govern {taxRate:0, split:{}}.
Our policy **Stavr Godinovich** (`stavr/stavr.nim`) speaks
consul.player.v1 (player_config / act{talk|bribe|vote|govern} / submit /
episode_end; spec fetched from the private repo
Metta-AI/cogame-cogsul coworld/docs/player-protocol.md via gh) and
improves the govern and talk lines where the rules doc is explicit:
talk runs a standing campaign (one public pledge + private pledges to
the two poorest other seats), vote stays self, bribe stays empty
(upfront Hearts don't bind the ballot), and govern taxes at the
constitutional cap and splits HALF the estimated treasury equally
between the two poorest other seats, keeping the rest — strictly better
than the baseline's 0-tax govern whenever we hold office. Upload needs
NO secret envs (no LLM in the player).

Protocol caveat: treasury rounding is undocumented (per-seat tax may be
floored, rounded, or fractional). The split is sized from a per-seat
floor estimate so it never requests more than the treasury can hold; if
govern replies ever get replaced by defaults in replays, this estimate
is the first suspect.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Vote the kingmaker line: when not consul, vote for the POOREST other
  seat instead of self — a weak consul taxes the leader (often us last
  rounds) less dangerously than a strong one; measure vs vote-self.
- Bribe-the-ballot probe: transfer 1-2 Hearts to the two poorest right
  before the vote and see if LLM seats reciprocate (rules say bribes
  don't bind, but LLMs may honor them).
- Final-round betrayal: on round == config.rounds, govern with
  split:{} (keep everything) — no future ballot can punish it.
- Leader targeting in talk: name the current Hearts leader in the public
  broadcast ("tax the leader") to steer LLM consuls' splits away from us.
- Dynamic backer count: buy ceil(n/2)-1 votes (minimum winning coalition)
  instead of a fixed 2 when seat count differs from 5.
- Bedrock seat: full LLM negotiation via the autopilot-style prompt
  (needs USE_BEDROCK) — the scripted seat cannot read promises at all.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Final-round betrayal | govern: on view.round >= config.rounds, tax at cap but split:{} (keep the whole treasury). Earlier rounds unchanged (half to the two poorest). Last round has no next ballot, and paying rivals there can hand them the win. | | | |
