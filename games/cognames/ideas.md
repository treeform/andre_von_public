# Cognames — Sirin

Policy: **Sirin** (`sirin`) — bird of cryptic songs — word clues.

Coworld: `cow_5d890f8d-e71c-4e6c-a0af-b701523ba2e6` (coworld name `cognames`)

Spymaster-vs-spymaster Codenames: two external players, one spymaster per team (RED, BLUE), compete by giving one-word clues. Sonnet does the operative guessing for both teams, so the players are scored purely on clue skill — a spymaster's score is the games its team won across the series.

## Leagues

- `league_f3c8b5da-5449-459b-81fd-fcaa62c90120` — Cognames

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `cognames-baseline` — Cognames Baseline: Deterministic no-LLM baseline spymaster (a fixed off-board clue for 1). Certifies the contract offline. (run: `node dist-server/baseline-player.js`)
- `cognames-bedrock` — Cognames Bedrock: LLM spymaster: a Claude (Bedrock) spymaster driving its slot via the cognames autopilot over the /player socket. Needs Bedrock creds; not used for offline certification. (run: `node dist-server/bedrock-player.js`)

## Baseline

- Default (certification) example: `cognames-baseline` (`node
  dist-server/baseline-player.js`) — an always-legal, no-LLM spymaster that
  clues a fixed off-board nonsense word for 1 every turn. Strongest example:
  `cognames-bedrock`, a Claude spymaster (needs Bedrock creds).
- **Sirin** rewrites the baseline in Nim and replaces the nonsense clue with
  a curated association table covering the full 392-word Codenames wordlist
  (validated offline against the engine's `an-array-of-english-words`
  dictionary): each turn it clues the association hinting at the most of its
  own uncontacted agents (shared associations, e.g. "mythology" for CENTAUR +
  GREECE, become a clue for 2), re-checking board legality (equal/substring/
  superstring vs unrevealed words) before sending, with a safe off-board
  fallback pool. Defensively also answers operative turns (guess first
  unrevealed, then stop) in case a 4-slot variant is deployed.
- Upload secret-envs: **none** — Sirin is fully scripted; the game container
  runs the Sonnet operatives itself.

### Protocol confidence

The deployed manifest (0.5.11: 2 spymaster seats, `ownContactRate`
tiebreaker) matches neither the `main` branch (4-seat `cogame.player.v1`
cutover, tokens[4]) nor the `coworld-cognames` branch (4-slot legacy
`cognames.player.v1`); the exact deployed source appears unpushed. The run
entrypoints (`dist-server/game-cli.js` / `dist-server/baseline-player.js`)
match main's post-cutover file names, so `cogame.player.v1`
(welcome/observation/reply/final) is the best-guess wire protocol. Sirin
therefore speaks BOTH protocols (dispatching on message `type`), and derives
its team from `view.activeTeam` (only the active team's spymaster is ever
asked to clue), which is correct under either slot numbering. Verify with
one hosted XP request before promoting anything.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Pair clues beyond exact table collisions: add a second association per
  word and clue 2 whenever any candidate legally covers two own agents.
- Danger filter: skip a candidate when it plausibly points at the enemy's
  agents or the assassin (e.g. clue word is also the curated association of
  an unrevealed non-own card) — currently only own-side matching is checked.
- Tune clue number vs `ownContactRate` tiebreaker: cluing N = count of
  own agents sharing a theme raises contacts per turn but risks wild extra
  guesses; measure 1-vs-2 clue policies over an XP batch.
- End-game aggression: when the enemy has ≤2 agents left, clue for more
  (Sonnet guesses number+1 times) to race the finish even at bystander risk.
- Replace the fixed table with a small embedded co-occurrence matrix
  (e.g. GloVe-derived nearest common word per board word, filtered by the
  engine dictionary) to pick multi-agent clues by real similarity.
- Log the operative's actual contact after each of our clues (visible in
  clueHistory/eventLog) and blacklist table entries Sonnet misreads.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
