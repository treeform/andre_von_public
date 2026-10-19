# Nomic Fable — Moska

Policy: **Moska** (`moska`) — Krylov's fable dog — loud beyond her size.

Coworld: `cow_e870bbd8-02f3-4191-9ab5-5e675eacff65` (coworld name `nomic-fable`)

Nomic as a coworld: three players take turns proposing rule changes; after debate and a majority vote, a judge LLM enacts passed proposals and executes the full rulebook each turn, updating a per-player and common key-value world state. The house rolls dice: a d6 adoption bonus for passed proposals and a d12 WINDFALL to a random seat every turn — by default the game is a lottery, and legislating what to do about that is the founding political question. Reach the victory threshold (initially 40, itself amendable) or hold the most points when the game ends after an undisclosed number of turns (10-15 in league play).

## Leagues

- `league_33f50eed-02ae-4b80-92d9-536cb900a15a` — Nomic Fable

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `scribe` — Scribe: Deterministic, zero-model baseline. Cycles templated proposals, debates by formula, votes by a stable hash of the proposal text. Bit-identical across runs. (run: `python -m nomic_fable.players.scribe`)
- `haiku-baseline` — Haiku Baseline: Minimal LLM player over AWS Bedrock (model id from BEDROCK_MODEL). Bounded calls with deterministic scribe fallbacks, so throttling never hangs an episode. (run: `python -m nomic_fable.players.haiku_baseline`)

## Baseline

Default example is `scribe` (deterministic, zero model calls; cycles
templated proposals, formulaic debates, hash-votes); strongest is
`haiku-baseline` (Bedrock). Our `moska` is a Nim rewrite of the scribe
shape with the upgrades the scoring math pays: it tracks state from
`game_start`/`turn_start`/`judge_ruling` and picks one unambiguous
judge-executable template by standing (universal +2/turn when leading
or 3-way tied; fewest-points catch-up when last; proposer +2 when
middle). It does not move `victory_points` — that bill cannot get a
second vote. Votes: aye on own bills; on others, aye only for
symmetric point gains that name no seat and don't touch the victory
threshold, else nay (nay is also the protocol default). Debate text
states the vote stance. Echoes `rid` on every reply; exits on `final`.
Zero model calls — upload needs NO secret-envs.

Protocol-confidence caveats: the protocol doc is field-level and full,
so confidence is high. Two reconstructions: `vote_request.proposal` is
tolerated as either a string or `{proposer, text}` object (exact shape
undocumented; proposer falls back to `turn_start.proposer`), and the
proposal reply is `{rid, text}` per the documented `proposal_request`
line. The python SDK conformance gate (`nomic_fable.players.conformance`)
cannot be run against a Nim binary — verify with a hosted XP episode
instead.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Capture one hosted episode's `vote_request` payload to pin the
  `proposal` field shape, then drop the dual-shape tolerance.
- Windfall riding instead of abolition: propose "the WINDFALL goes to
  the player with the fewest points" when we trail — same catch-up
  logic the median voter likes, but state-aware.
- Time the victory-threshold amendment: docs say the game ends at an
  undisclosed turn in 10-15, so from turn 9 onward switch to pure
  point-grab proposals (threshold bills waste a turn if the game ends).
- Model the two opponents' vote patterns from `vote_reveal` (scribe
  hash-votes ~50/50; LLMs vote content) and tailor proposal symmetry to
  the swing voter.
- Mine `judge_ruling.rejected_ops` for our own rejected operations and
  auto-simplify the failing template (drop clauses the judge would not
  execute).
- Debate order exploit: the second debater sees the first speech —
  when ours contradicts the earlier speech, name the disagreement
  explicitly to sway an LLM voter.
- Aye catch-up bills when we are last: `voteAye` only treats
  every/all/each-player text as symmetric, so we currently nay
  "fewest points" even when we are the beneficiary and the other
  trailer is the swing vote.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Position-aware proposals: drop doomed victory_points cuts. Field 2026-09-01: relh/`co-gas-nomic-fable-frontier-relhalpha:v5` leads at 1584.6 wr 0.71 mean 41.5; we are #7/7 at 1403.7 wr 0.14 mean 28.6. League victory is 40 (variant `standard-3`); winners cluster at 40–42 (they race the threshold). Rule 202: pass pays proposer +3 plus 1d6, fail docks -1. A 15+ lead threshold bill needs both rivals to let us win — they nay, we eat -1 and skip a passable turn. Blind cycle also tables catch-up while leading (feeds the trailer) and abolishes windfall (EV 6.5/3 ≈ 2.17/turn) for a worse flat +2. | `chooseProposal` picks by standing: catch-up +3 to fewest when last (other trailer is the swing vote); universal +2/turn when leading or 3-way tied (passable race to 40, keep windfall); proposer +2 when middle. Delete the victory_points amendment. | | | |
