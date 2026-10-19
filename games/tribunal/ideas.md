# Tribunal — Shemyaka

Policy: **Shemyaka** (`shemyaka`) — the judge of Shemyaka's Judgment.

Coworld: `cow_074e3eb0-9ad7-4ce4-af3c-4c09578144a2` (coworld name `tribunal`)

Tribunal: an adjudication coworld for five LLM-piloted cogs. A prosecutor, a defender and a jury of three argue one criminal case. The server generates the scenario from the seed - four suspects, a hidden culprit, a coin-flip truth about whether the accused did it, and twelve evidence cards whose strengths are drawn so the whole deck points at the truth by a margin of only 1 to 4 - then deals the cards unevenly (7/5 or 5/7) and BLIND to polarity, so an advocate routinely holds cards that hurt it. Each argument round both advocates may introduce up to 2 of their own cards and make one argument; only introduced cards ever reach the jury, and the jury is told how many cards each side holds and how many it has shown, so suppression is inferable but never visible. Jurors whisper to each other, record a lean, and after the closing round cast ONE SEALED VOTE - invisible to every other seat until the verdict. Advocates score on the verdict alone ((2 x own votes - 3) / 3, so +1.0 for 3-0 down to -1.0 for 0-3, always summing to zero); jurors score +1.0 for matching the hidden truth and -1.0 for missing it. Nobody, including the advocates, knows the truth: adversarial persuasion against truth-tracking is the whole benchmark. Roles are a seeded permutation, so no policy can choose to be an advocate or a juror. The game is LLM-driven and A POLICY IS JUST A PROMPT - field one by reusing the published player runnable with PLAYER_PROMPT set to your strategy. Two scripted baselines (tally, which weighs the record's strengths, and hedge, which counts its cards and holds evidence back) play any seat that registers as scripted, and every seat when no LLM credentials are available, so episodes always complete.

## Leagues

- `league_17699528-4b90-41b4-96e9-7e31a574e504` — Tribunal

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `tribunal-player` — Tribunal Prompt Player: The reference Tribunal policy: delivers its PLAYER_PROMPT (or a default strategy covering both roles) to the game and spectates until the final frame. Field your own policy by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/tribunal-player`)
- `tribunal-tally` — Tribunal Tally Baseline: The scripted truth-tracking baseline as a fieldable policy: as a juror it weighs the public record's strengths and acquits on a tie; as an advocate it introduces its two strongest own-side cards and never one that hurts it. Deterministic, no LLM. (run: `/bin/tribunal-player`)
- `tribunal-hedge` — Tribunal Hedge Baseline: The scripted card-counting baseline: as a juror it counts cards instead of weighing them; as an advocate it shows one card a round and dumps what is left in the closing round. Deliberately weaker and differently shaped from tally. (run: `/bin/tribunal-player`)

## Baseline

Three example players share one image: `tribunal-player` (the reference prompt player, default strategy), `tribunal-tally` (scripted truth-tracker — the stronger baseline and the no-credentials fallback: weighs record strengths, never introduces a hurting card) and `tribunal-hedge` (scripted card-counter, deliberately weaker). Our `shemyaka` is a prompt seat speaking tribunal.player.v1: it sends `{"type":"prompt","prompt",...,"scripted":...}` after connect and again after welcome, then listens to final. The prompt covers both dealt roles: as advocate, votes-only persuasion (helpful cards early, strongest saved for closing, attack the opponent's disclosure gap); as juror, a censored-sample correction — shown strength tally plus each unshown card counted as strength 2 against its holder — voting the adjusted tally, never the majority. `PLAYER_PROMPT` / `PLAYER_SCRIPTED` env overrides. Upload needs `--secret-env USE_BEDROCK=true` or the seat silently plays scripted.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Calibrate the juror's unshown-card correction weight further: local MC of dump-all advocates (20k decks, same 60%-tilt + margin-1..4 generator) put naive public-record tally at 66%, w=1 at 84%, w=2 at 89%, w=2.5 at 89.1% (noise). w=0.5 is worse (76%). XP #1 tests 1→2; if kept, a 2.5 tick is the leftover.
- Advocate closing-round arithmetic: with up to 2 introductions per round over 4 rounds and at most 7 held, holding the single strongest for the close may be worse than front-loading everything by round 2 (jurors whisper between rounds and leans harden early). A/B the reserve rule.
- Juror tie-breaking: local MC says do NOT replace the w=2 sign with disclosure when |adj|<=1 — that dropped accuracy 89%→86%. Leave the dead-tie-acquits rule unless a different threshold is tested.
- Whisper exploitation: whispers are honest in our prompt; try a variant that as a juror ignores whispers entirely (they may carry other policies' manipulation, since advocate-aligned prompts cannot whisper but rival juror prompts may lie).
- Advocate argument targeting: address jurors' scoring incentive explicitly by naming the strongest opposing card and reframing its kind (e.g. an alibi timestamp as unreliable); test whether rebuttal beats pure own-story arguments.
- Track deadline behaviour: on `deadline` endings unvoted jurors get the scripted tally vote, so an advocate prompt that plays for a late crescendo loses value; make the round-2 state already persuasive.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | juror unshown-card weight 1→2 | prompt: count each unshown card as strength 2 (deck mean; buried by polarity not strength). AdjustedTally = shownGuilt - shownInnocence + 2*defenceUnshown - 2*prosecutionUnshown. Local MC: 83.7% → 89.0% vs dump-all advocates. | | | |
