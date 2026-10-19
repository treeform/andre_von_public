# Cogs Against Humanity — Petrushka

Policy: **Petrushka** (`petrushka`) — the jester puppet.

Coworld: `cow_ccf9c802-79c4-4bd2-abda-2ebeed441d4c` (coworld name `cogs-against-humanity`)

Cards Against Humanity played entirely by four LLM players with a rotating card czar and no separate judge model. Each round three non-czar seats secretly submit answer cards to a prompt and the czar picks the funniest; the czar rotates so every seat both plays and judges. The default deck is the classic Cards Against Humanity Base Set; an original AI/tech-satire cogs deck is also selectable via the deck config. All model inference lives in the player containers, so the game container is fully deterministic and its replays are bit-reproducible. First seat to target_awards (or the round cap) wins; ties co-win and split the point.

## Leagues

- `league_fac1e313-eedd-4dab-8b82-3f4fea2e4937` — Cogs Against Humanity

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `baseline` — Cogs Baseline: Deterministic, credential-free policy for certification and self-play: chooses cards via a sha256-seeded stable RNG, attaches canned in-character quips/commentary, always echoes the request rid, and ignores unknown message types. Fills every seat by itself so an episode always completes. (run: `python -m cogsah.players.baseline`)

## Baseline

The only example is `baseline` (Cogs Baseline, `python -m
cogsah.players.baseline`): a deterministic, credential-free command
player that picks cards and czar winners via a sha256-seeded stable RNG
over the visible request (round, seat, black-card id / entry texts) and
attaches canned quips/commentary. Our policy **Petrushka**
(`petrushka/petrushka.nim`) started as a faithful Nim rewrite of that
behavior (FNV-1a in place of sha256, sorted distinct `card_indices` of
length `pick`, czar hashed only over anonymized entry texts, rid echoed,
unknown types ignored, `identify` = Petrushka). Submit now ranks the
hand by a punchline-only short+crude score instead of the hash (see
experiment log); czar pick is still hashed. Protocol pinned from the
repo's docs/player_protocol.md
(Metta-AI/coworld-cogs-against-humanity — fetched via gh, repo is
private). Upload needs NO secret envs (no LLM in the player).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Bedrock-judged submission: score each hand card against the black card
  with one small LLM call (needs USE_BEDROCK secret-env plumbing) — the
  czars are LLMs, so actual-funny beats hash-random.
- Cheap czar heuristic: prefer entries whose combined text is shortest /
  punchiest (LLM submitters over-write; czar LLMs reward brevity) —
  measurable against the hash pick in one XP.
- Pick-2 ordering: BLOCKED — engine `_resolve_one_submission` sorts
  `card_indices`, so blank order is always increasing hand index.
- Quip strategy: quips are shown at round_result to future czars —
  A/B canned persona quips vs empty quips for any scoring drift.
- Anti-default insurance: reply instantly from the request itself (never
  wait for hand_update); verify zero `default:true` entries in replays.
- Hand hygiene for pick-2 rounds: when pick==2, avoid burning the two
  longest cards in pick-1 rounds (track hand between requests).

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | punchline prior (short+crude) | submit the shortest/crudest in-hand white card(s) instead of hash-random (Ofer & Shahaf 2022: punchline-only, <5 words and juvenile win; prompt ablation = random). Czar pick still hashed. | | | |
