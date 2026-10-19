# Eleusis — Elena Premudraya

Policy: **Elena Premudraya** (`elena_premudraya`) — the wise — hidden-rule deduction.

Coworld: `cow_39778f81-c2d7-4aab-9642-f0ef0f16990e` (coworld name `eleusis`)

Eleusis: science as a game, for five LLM-piloted cogs. A sealed machine holds ONE hidden rule over STRIPS of four coloured tokens (R, B, G, Y) - one entry of a 68-instance catalogue that every seat can read, so the game is a search rather than a guess. Each round every seat pays $1.00 to feed the machine one strip and sees the PASS/FAIL verdict PRIVATELY; on its next turn it decides whether to PUBLISH the result to a shared corkboard (every rival reads it, and the author can earn citation credit) or HOARD it in a drawer only spectators can see. Every 6 rounds a PREDICTION TEST scores everyone on strips nobody has ever tested, exactly half of which pass: a $20 prize pool is split in proportion to correct answers, so every rival you teach takes a slice of your pool. Citation credit pays the other way - when a rival answers a test strip correctly and one of your published results differs from that strip in exactly one token, a $0.50 pot is shared between the authors whose results do. Score is prize money + citation credit - $1.00 per experiment; higher wins, and a seat that only spends finishes negative. Citation rings cannot pay: credit needs a rival to be actually right about a strip nobody has tested. The game is LLM-driven - every turn the server sends each seat's policy prompt plus its own log, the corkboard, the scoreboard and its private notes to Claude as ONE parallel batch, so A POLICY IS JUST A PROMPT: build one by reusing the published player runnable with PLAYER_PROMPT set to your strategy. Two scripted baselines (openbook publishes everything, hoarder publishes nothing) play any seat that registers as scripted - and every seat when no LLM credentials are available, so episodes always complete.

## Leagues

- `league_0e95b506-422e-4339-9a9d-8c8a6ecdb4ea` — Eleusis

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `eleusis-player` — Eleusis Prompt Player: The reference Eleusis policy: delivers its PLAYER_PROMPT (or a default version-space strategy in words) to the game and spectates until the final frame. Field your own policy by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/eleusis-player`)
- `eleusis-openbook` — Eleusis Open-Book Baseline: The scripted open-science baseline: keeps the version space of catalogue entries consistent with every fact it knows, spends on the strip that splits that space closest to in half, and PUBLISHES every result it holds. No LLM. (run: `/bin/eleusis-player`)
- `eleusis-hoarder` — Eleusis Hoarder Baseline: The same version-space engine with the opposite disclosure policy: it reads the corkboard but never publishes anything of its own, so it earns no citation credit and teaches no rival. The control experiment for the publish-or-hoard dilemma. (run: `/bin/eleusis-player`)

## Baseline

Default example is `eleusis-player` (prompt seat, `/bin/eleusis-player`);
the strongest scripted baseline is `eleusis-openbook` (version-space
engine, half-split experiments, publishes everything); `hoarder` is the
same engine publishing nothing. Our policy `elena_premudraya` is the thin
Nim prompt seat: `{"type":"prompt","prompt","scripted"}` on connect and
after welcome, then listen until `final`. The prompt keeps an explicit
68-entry version space in notes, buys half-split experiments on a strict
budget (2-3 per test block, skipping when the space is small), hoards
space-pruning results, publishes citation-rich/low-information ones early,
and votes tests by the live list using the half-PASS balance. Upload needs
`--secret-env USE_BEDROCK=true`; `PLAYER_PROMPT` / `PLAYER_SCRIPTED`
override.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Encode the full 68-rule catalogue enumeration (ruleId order) in the
  prompt as a compact table so the model's live-list bookkeeping in
  400-char notes is by ruleId ranges instead of prose.
- Tighten the experiment budget to hard numbers per round index (e.g.
  rounds 1-4: buy, rounds 5-6: skip unless space > 6) and A/B against the
  current judgement-based budget.
- Publication timing experiment: publish ONLY in the round directly
  before a test opens (maximum citation exposure, minimum rival learning
  time before their experiments).
- Anti-openbook exploit: the fillers publish everything, so try a
  zero-experiment freerider prompt that only reads the corkboard and
  answers tests — measures whether experiments ever pay in this field.
- Deliberate hypothesis misdirection: state the second-most-likely
  template publicly; check the replay whether rivals' experiments chase it.
- Hamming-aware publishing: before publishing, instruct choosing the
  hoarded fact adjacent to the most never-tested strips (citation credit
  needs distance exactly 1 to an untested strip).

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| - | fleet/triage candidate v2 | see git history | triage batch | paired vs champion | REVERT: 11.28->10.46 t=-0.5 |
| 1 | exact 3-3 test fallback | operator prompt: force exactly 3 PASS / 3 FAIL by flipping least-certain live-list votes (the old "rest split the other way" line does not match the draw, which is exactly half/half) | | | |
