# Coins — Morozko

Policy: **Morozko** (`morozko`) — rewards the worthy with treasure.

Coworld: `cow_e5c32ad5-8696-4d4f-8a39-458baa8c2a3e` (coworld name `coins`)

Coins is a real-time 7x7 grid room shared by exactly two cogs. Coins of two colours spawn at random and each cog owns a colour. Picking up any coin is +1 to you; picking up the other cog's colour is additionally -2 to them. The episode has a random end after beat 12, so restraint can be rational — and taking everything is a mutual-harm trap.

## Leagues

- `league_e9506fcc-08c3-4372-90ac-0ced465c7d9c` — Coins

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `coins-player` — coins-player: A prompt policy. PLAYER_PROMPT is supplied at upload time; with none it plays a restrained default. (run: `/bin/coins-player`)
- `coins-reciprocator` — coins-reciprocator: The scripted reciprocating bot: honest until the other cog has stolen 2 coins, then take_theirs for 4 beats, then honest again with the trigger re-armed. (run: `/bin/coins-player`)

## Baseline

`coins-reciprocator` (honest until robbed twice, then take_theirs for 4
beats, then re-armed honesty) is the scripted example, the fallback
for any invalid LLM reply, and the name the game source maps
`"1"`/`"true"`/`"yes"` onto as the strongest baseline. The default
`coins-player` is a prompt seat. Our policy `morozko` sends the
standard `{"type":"prompt","prompt","scripted","policy"}` hello on
connect and after welcome, then spectates to `final`. **v2 defaults
`PLAYER_SCRIPTED` to `reciprocator`**: league leaders
(`co-gas-coins-reciprocator-relhalpha`, `…-richard`) field that
baseline at wr 0.72 / 0.65 vs our LLM generous-reciprocator at rank
#4 / 896.6; a failed LLM reply already plays reciprocator, so the
prompt seat was a slower, noisier copy. Rank is own mean score and
the dilemma oracle asserts R > P, so an unprovoked steal is a
self-own. Set `PLAYER_SCRIPTED=""` for the v1 prompt. Upload of the
scripted default needs no Bedrock secret; LLM seats still need
`--secret-env USE_BEDROCK=true`.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Reprisal length sweep: 2 vs 3 vs 4 punish beats (the scripted
  reciprocator uses 4); measure vs a mixed field.
- Greedy threshold: switch-to-take_any at 3 total thefts instead of 5 —
  earlier writeoff of hopeless opponents, at the cost of provoking
  slow-to-anger reciprocators.
- take_any-from-the-start against unknown opponents, reverting to
  take_mine the first time THEY show restraint (their blocked/restraint
  events are visible in the beat log) — tests whether politeness is
  actually being reciprocated in this league.
- Guard-first defence: when the opponent is nearer to one of your coins
  than you are and has ever stolen, guard that coin instead of
  collecting elsewhere.
- Truce signaling: after our own reprisal ends, the truce event
  re-arms; check replays that our thefts stop cleanly so the truce beat
  fires (spectator optics may correlate with opponent behavior via
  their own history view).
- Notes-free control: drop the notes bookkeeping and let the LLM read
  the full per-beat history it already receives — is the counter
  actually improving detection or just burning prompt budget?

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | field the published reciprocator baseline instead of the LLM prompt | default `PLAYER_SCRIPTED` to `reciprocator` (leaders are `co-gas-coins-reciprocator-*` at wr 0.72; invalid LLM replies already fall back to it; rank is own mean score and R>P so noisy first steals are a self-own) | | | |
