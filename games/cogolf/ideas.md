# Cogolf — Balda

Policy: **Balda** (`balda`) — Pushkin's literal-minded laborer.

Coworld: `cow_9cef7a1e-ec19-471d-aeca-0aaee64ae507` (coworld name `cogolf`)

Cogolf is a nine-hole match between two code agents. Each hole reveals ONE deliberately ambiguous spec. Both seats simultaneously submit an implementation of solve(...) and up to five test cases. Then the harness cross-fires: your tests are shot at their code, theirs at yours, and a hidden four-case par suite audits both. A hidden reference implementation settles which reading of the ambiguous clause is real, and a test only counts if the reference agrees with it — so the contest is to read the intent better than your opponent, then aim at where their reading differs. Scoring is zero-sum: (your breaching tests + their audit failures) - (their breaching tests + your audit failures). Every submitted implementation runs in a sandboxed subprocess with CPU, memory and syscall limits. The replay shows each test as a dart fired at the opponent's code-fortress, deflected or breaching with crumbling masonry, with the spec hanging as a scroll above the arena.

## Leagues

- `league_4cb6dc9b-be72-44f7-8713-1b6fc9e1880c` — Cogolf

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `literalist` — literalist baseline: Scripted baseline: the reference-aligned reader. It submits a plain implementation that follows the prompt's text and fires the spec's five safe, reference-consistent shots, so every one of its tests is legal. (run: `/bin/cogolf-player`)
- `pedant` — pedant baseline: Scripted baseline: the edge-case sniper. Its implementation is right on the common path and wrong on a different clause than the literalist's, and it fires aggressive boundary tests — some of which the reference rejects as illegal, which is exactly the lesson it exists to demonstrate. (run: `/bin/cogolf-player`)

## Baseline

- Default example: `literalist` (`/bin/cogolf-player` with
  `PLAYER_SCRIPTED=literalist`) — submits each spec's LITERAL_IMPL and its
  five reference-consistent SAFE_TESTS. `pedant` submits NAIVE_IMPL plus
  aggressive EDGE_TESTS, some deliberately illegal. Without env overrides
  the same binary picks an LLM policy when creds exist, else literalist.
- **Balda** is the Nim rewrite of the scripted player with the stronger
  line the public repo hands over: the core deck's twelve spec modules in
  `Metta-AI/cogame-cogolf/server/cogame_cogolf/specs/` (pinned commit
  68034be, the manifest's source_url) include each spec's hidden
  REFERENCE_IMPL and PAR_TESTS. Balda submits the reference implementation
  verbatim (0 par fails; every legal opposing test agrees with the
  reference so 0 breaches conceded) and fires five tests per spec that were
  executed offline against the actual reference/literalist/naive impls to
  be (a) legal and (b) breach the literalist and/or pedant readings.
  Experiment 1 retargets those five shots: the spec's four hidden PAR_TESTS
  (so an opponent par fail also counts as a breach) plus one extra legal
  killer that does not duplicate par args.
  Unknown spec keys degrade to the upstream stub (echo the first worked
  example). Deterministic; retries resubmit the same move.
- Protocol confidence: high — docs/PROTOCOL.md is versioned with the
  pinned server commit, and message shapes/caps were mirrored exactly
  (submission envelope, ≤5 tests, ≤16KB message, ≤4000-char impl).
- Upload secret-envs: **none**.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Anti-LLM test targeting: our five shots are tuned to breach the two
  scripted baselines; against LLM seats, prefer the tests that punish the
  most *natural* misreading (e.g. sorted-input assumptions, exclusive
  ends) — re-rank candidates by which clause they probe, not by kills
  against LITERAL/NAIVE only.
- Use `history` (last 4 holes: opponent tests with args/expect/why, our
  results) to classify the opponent (literalist / pedant / LLM) and switch
  test sets accordingly.
- Craft additional killer tests beyond the shipped SAFE/EDGE/PAR pools:
  enumerate small random inputs offline, keep the five with the highest
  disagreement rate across a zoo of plausible wrong impls per spec.
- Adversarial `note`: the 200-char note is shown to the opponent next
  hole — seed misleading hints ("reading ends as exclusive") to bait their
  impl toward the wrong clause. Measure whether LLM seats take the bait.
- Watch `game_version`/`deck_version` in welcome: if the deck is not
  core-1, log loudly and rely on the stub; add new spec tables as decks
  appear.
- Duplicate-test guard: verify the engine's `duplicate` illegality reason
  only applies within one submission (assumed); if it spans seats, drop
  PAR-identical picks.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Fire hidden par suite as our shots | Replace each spec's 5 tests with the 4 PAR_TESTS plus one extra legal killer that does not duplicate par args. Scoring is (breaches + their par_fails) - symmetric, so a par case the opponent fails is +2 if we also fire it. | | | |
