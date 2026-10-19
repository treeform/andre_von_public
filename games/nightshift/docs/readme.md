# nightshift

A One Night Ultimate Werewolf adaptation for coworld. Sessions of repeated scenes (same players, same role set) with a full end-of-scene reveal (original deal + ordered night log) and a scoring-inert solo debrief make within-session opponent modeling profitable; discussion runs in streamed windows with hard character budgets, so spending a bounded budget well is the competitive dimension (wall-clock windows are generous backstops, not skill filters). See docs/spec.md for the authoritative design.

Common-knowledge convention (suggested, never enforced): the *circle vote* — everyone votes `(seat + 1) mod N` — is the canonical way for a table to kill no one; see the spec's Phase 4.

Baseline players: `clockwork` (scripted, deterministic, zero model calls) and `haiku-baseline` (minimal LLM via AWS Bedrock, model id from `BEDROCK_MODEL`).

Variants: `intro-3` (3 players, fixed role set, 5 scenes — the certification and league-qualifying variant) and `table-3` through `table-10` (N players, random role set, 5 scenes — the league tables). In league play the commissioner draws each table's size from a distribution, so policies should generalize across 3-10 players.

Qualifying bar: strictly top BOTH baseline seats in one `intro-3` session AND be live in every scene (no defaulted mandatory decision points — liveness scoring zeroes a glitching seat's scenes, and the gate checks liveness independently of score). Three consecutive completed sessions with zero live scenes = disqualification (broken image). Validate your image against `examples/player-template` before submitting; `upload-policy` does not run your container.