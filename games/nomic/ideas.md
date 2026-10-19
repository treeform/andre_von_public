# Nomic — Tsar Gorokh

Policy: **Tsar Gorokh** (`tsar_gorokh`) — the legendary lawgiver of old.

Coworld: `cow_64226600-1cf0-484a-95e7-155c0f0273ce` (coworld name `nomic`)

Three flavorful LLM delegates act inside and rewrite a living game: natural-language moves, self-amending rules, secret votes, deterministic Fate, and binding schema-checked Opus 4.8 rulings. Point victory starts at 100, checked after full circuits, with a 45-turn cap.

## Leagues

- `league_ee2f409e-20a9-4501-ad4d-14116bc4b4a0` — Nomic

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `baseline` — Nomic Baseline: Deterministic no-network policy for certification; passes actions, proposes harmless enactments, and votes AYE. (run: `python -m nomic.players.baseline`)

## Baseline

Only one example ships: `baseline` (deterministic, no network — passes
actions, proposes harmless enactments, votes AYE). Our `tsar_gorokh` is
a Nim rewrite of exactly that shape as a command player: pass on
`action_request` and the repair, cycle five clear harmless enactments
on `proposal_request` (each adoption pays the proposer 3 points, and a
table of AYE voters adopts everything), debate with a short supportive
text + `vote_intent: "aye"`, vote `{vote:"aye", reason}`. Zero model
calls — upload needs NO secret-envs.

Protocol-confidence caveats (no source repo; the manifest protocol page
is a summary, not a field-level spec):
- Reply field names are reconstructed. Confident: `rid` echo, vote
  `{vote:"aye"|"nay", reason}`, debate `{text, vote_intent}`, proposal
  kinds enact|amend|repeal|transmute. Guessed: action reply field
  (we send both `action` and `text` = "pass"; malformed resolves to
  pass anyway, which is the intended move) and proposal reply shape
  (`{rid, kind:"enact", text}`); if a hosted run shows proposals
  defaulting, capture a real player exchange from the /global stream
  and fix the field names.
- Message shapes of `game_start`/`turn_start` are unread by the policy
  (baseline behavior is unconditional), so unknowns there are inert.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Verify the proposal reply field names against a hosted
  qualifier-1-turn episode (deterministic judge) before league play.
- Stop voting AYE on opponents' proposals once past the two unanimity
  circuits: AYE gives every rival proposer +3; a selective NAY (own
  proposals and harmless ones only) slows their point income.
- Use real actions instead of pass: the docs say active rules can
  authorize point-scoring moves; parse `game_start`/`turn_start` rules
  text for "gain"/"points" patterns and attempt the cheapest scoring
  move, keeping pass as the repair fallback.
- Propose a self-favoring but veto-proof enactment ladder (e.g. "the
  proposer of an adopted rule gains 1 extra point") once opponents'
  vote behavior is measured.
- Watch for transmute attempts on the five protected procedural rules
  and always vote NAY on them — protection is our stability.
- Exploit the 45-turn cap tie rule: co-winners split the point, so near
  the cap prefer NAY on anything that pushes a single rival past us.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
