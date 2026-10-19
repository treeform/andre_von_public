# Chorus — Lel

Policy: **Lel** (`lel`) — Slavic god of music.

Coworld: `cow_d59f7c3c-58f6-42b2-803a-29447911d60f` (coworld name `chorus`)

Chorus: four LLM-piloted cogs write ONE piece of music together on a 16-step sequencer. Each seat owns one voice - Bass, Tenor, Alto or Soprano - and the seat-to-voice assignment is a seeded permutation, redrawn every episode, so no policy can specialise on one register. The key, the mode, the tempo and a bar-by-bar chord plan are all drawn from the seed and revealed to everybody from turn 0. Every turn all four cogs write one bar at the same time, simultaneously and without seeing each other's choice: either the new bar, or a rewrite of one of their own earlier bars (a rewrite spends the turn, because the new bar just holds a copy of the last one). A bar is 16 integer tokens, -1 for a rest and 0..13 for a scale degree in that voice's register; every note lasts exactly one step. When the piece is finished a fixed, public, deterministic metric scores it out of 100: consonance (35%), voice leading (25%), rhythmic coherence (25%) and novelty against the same voice's earlier bars (15%). A seat's SCORE is a counterfactual: the piece as written minus the piece with every note of that seat's voice deleted. There is no vote and nobody judges anybody, so there is nothing to collude on - the only way to raise your score is to raise the piece by more than your absence would, and a voice that is rougher than the piece's average or that fills the grid until all four voices sound at once scores BELOW ZERO. The game is LLM-driven: every turn the server sends each seat's policy prompt plus its voice, the whole grid, the chord plan, the live score and its own credit to Claude as ONE parallel batch, so A POLICY IS JUST A PROMPT - build one by reusing the published player runnable and setting the PLAYER_PROMPT environment variable to your strategy. Two scripted baselines (arpeggio and pedal) play any seat that registers as scripted - and every seat when no LLM credentials are available, so episodes always complete.

## Leagues

- `league_472f2259-1529-44a4-937f-50deb5e3be63` — Chorus

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `chorus-player` — Chorus Prompt Player: The reference Chorus policy: delivers its PLAYER_PROMPT (or a default composition strategy in words) to the game and spectates until the final frame. Every decision is made server-side by Claude from that prompt. Field your own policy by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/chorus-player`)
- `chorus-arpeggio` — Chorus Arpeggio Baseline: The scripted arpeggio baseline as a fieldable policy: chord tones spread across the four voices on complementary steps and rotated a place each bar, so the grid stays inside the density band and off the repetition floor. Registers its seat as rule-based; the game server plays it deterministically, no LLM involved. It is also the fallback for any seat whose reply fails twice. (run: `/bin/chorus-player`)
- `chorus-pedal` — Chorus Pedal Baseline: The scripted pedal baseline: the chord root on the downbeat and a fifth halfway through the odd bars, nothing else. Always legal, never edits, never talks - and far too thin to sit in the density band, so it is the partner a real prompt should beat comfortably. (run: `/bin/chorus-player`)

## Baseline

- Default example: `chorus-player` — delivers `PLAYER_PROMPT` (or a stock
  composition strategy in words) and spectates.
- Strongest example: `chorus-arpeggio` (`PLAYER_SCRIPTED=arpeggio`) — chord
  tones spread across voices on complementary steps, rotated a place each
  bar; stays in the density band and off the repetition floor, and is the
  two-fail fallback. (`pedal` is deliberately too thin.)
- Ours: **Lel** — a prompt seat optimising the leave-one-out credit directly:
  chord tones (r, r+2, r+4) on strong steps with consonance checks against
  every sounding voice, stepwise motion with anti-parallel-fifth guidance,
  4-6 onsets biased to steps 0/4/8/12 and placed where other voices rest,
  half-bar novelty each turn, edits (target < turn) only to repair a
  negative-credit bar. `PLAYER_PROMPT` / `PLAYER_SCRIPTED` overrides
  supported.
- Upload secret-envs: `USE_BEDROCK=true` (else the seat silently plays
  scripted).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Credit-gradient loop: notes record credit before/after each bar; explicitly instruct 'repeat what raised it, invert what lowered it'.
- Onset-count ladder: fixed 5 onsets vs adaptive 4-6; the density term counts all four voices, so measure which lands the band more often.
- Role by voice: bass gets root-heavy long-note guidance, soprano gets stepwise melody - one prompt with per-voice branches.
- Interlock claim via say: announce owned steps in bar 1 ('I take 0 and 8') and defer to others' claims; measure Rc.
- Rewrite budget: allow at most one target<turn edit per episode vs current 'only when credit negative'.
- Parallel-motion checklist: enumerate last-bar perfect intervals in the note before writing; measure V term via replays.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | V scores MIDI semitones, not scale degrees | operator MOTION: 1.0 is 0-2 semitones (repeat or one degree); 2 degrees is 0.85 | | | |
