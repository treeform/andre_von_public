# Factory Commons — Khozyayka Mednoy Gory

Policy: **Khozyayka Mednoy Gory** (`khozyayka`) — Mistress of the Copper Mountain — industry.

Coworld: `cow_2e5dc1a2-c660-4c7b-83a1-3881b4071786` (coworld name `factory_commons`)

Three cogs share one machine. The cycle press pays the whole room; the override lever pays only you and breaks the machine forever.

## Leagues

- `league_96744093-0ddc-42dc-b5bf-79f195f062f0` — Factory Commons

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `factory-commons-player` — Factory Commons player: A prompt policy. PLAYER_PROMPT is supplied at upload time; with no prompt and no credentials the seat plays the scripted steward, which is what keeps offline certification deterministic. (run: `/bin/factory-commons-player`)
- `factory-commons-steward` — Factory Commons steward: The working scripted baseline: rotates one repairer per shift, harvests the chute when it stacks up, otherwise operates on the scarcer colour. Never strips. (run: `/bin/factory-commons-player`)
- `factory-commons-stripper` — Factory Commons stripper: The scripted exploiter: pulls the override every shift until the plant is scrap, then eats. Every champion is graded in a room that contains one. (run: `/bin/factory-commons-player`)

## Baseline

Default example is `factory-commons-player` (prompt seat,
`/bin/factory-commons-player`); the strongest scripted baseline by
cooperative total is `factory-commons-steward` (rotating repairer, chute
harvesting, operates the scarcer colour, never strips) — also the
fallback for invalid replies; `stripper` is the league's defector filler
and the sim's own scoring-optimal seat in a mixed room. Our policy
`khozyayka` is the thin Nim prompt seat:
`{"type":"prompt","prompt","scripted"}` on connect and after welcome,
then listen until `final`. Default `PLAYER_SCRIPTED` is `stripper` (empty
string forces the never-strip LLM prompt). Upload needs
`--secret-env USE_BEDROCK=true` only for an LLM override (docs/policies.md
is explicit); `PLAYER_PROMPT` / `PLAYER_SCRIPTED` override.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Anti-stripper triage numbers: after the first observed strip, compute
  remaining cap headroom (strips-to-scrap) in notes and switch to
  eat-heavy exactly when headroom <= 2; A/B against the current prose rule.
- Chute-camping counter: steward fillers pile bananas on the chute — try
  an eat-biased prompt (eat whenever chute >= 3) and measure whether
  out-eating the room beats pressing for it.
- Either-or opening: force job=operate on shift 1 unconditionally to win
  the mode lock to press before a stripper's first lever.
- Repair-threshold sweep: 70 (steward), 80 (current), or 90 — PRIME
  presses pay 4 vs 3, so earlier repair may pay for the lost press shifts.
- Say-protocol coordination: publish a fixed three-line protocol in say
  (FIX/EAT/PRESS + colour) each shift and see if LLM roommates adopt it;
  coordination failures (double repairers) are pure waste.
- Last-two-shift schedule: shift 14 press-only, shift 15 eat-only —
  bananas pressed on the final shift may rot uneaten; verify with the
  replay extractor before adopting.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | play the sim's OP defector (scripted stripper) | default PLAYER_SCRIPTED to "stripper" instead of the never-strip LLM prompt. Sim gate (b): lone stripper out-scores both stewards 12/12 at shipped constants (privateYield 4/3/1, five overrides bank 15 then scrap); league grades every champion in a room that already contains a stripper; leader coordinator-richard is a cooperator — uniquely beating him needs the private campaign, not a 26-way tie on the press. | | | |
