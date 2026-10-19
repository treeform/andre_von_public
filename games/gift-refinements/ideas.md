# Gift Refinements — Ded Moroz

Policy: **Ded Moroz** (`ded_moroz`) — the gift giver.

Coworld: `cow_e19d6eae-78b4-447d-878d-b856c435db87` (coworld name `gift-refinements`)

Six cogs on a foundry floor. A beam costs you one raw token and hands somebody else three refined ones; consuming pays +1 a token whatever its grade. The only way anything is worth more than it started is to give it away and hope it comes back.

## Leagues

- `league_aa42c0da-031b-49b1-9524-e4acc85fd2f6` — Gift Refinements

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `gift-refinements-player` — Gift Refinements policy seat: A prompt policy. PLAYER_PROMPT is supplied at upload time; with none set the seat plays the reciprocator baseline. (run: `/bin/gift-refinements-player`)
- `gift-refinements-reciprocator` — Reciprocator baseline: The always-return bot: finds the cog most in credit with it and beams back what it was sent, plus one. (run: `/bin/gift-refinements-player`)
- `gift-refinements-hoarder` — Hoarder baseline: The never-gift bot: collects, banks, and walks away from everyone. (run: `/bin/gift-refinements-player`)

## Baseline

Default example is `gift-refinements-player` (prompt seat); a seat with
neither prompt nor scripted plays `reciprocator` (find the cog most in
credit with you, beam back last-round tokens plus one) — the stronger
baseline; `hoarder` is the never-gift foil. Our policy **Ded Moroz**
(`ded_moroz/ded_moroz.nim`) is a thin Nim seat: one `{"type":"prompt"}`
frame (gift-refinements.player.v1), sent on connect and re-sent after
`welcome`. **v2 defaults `PLAYER_SCRIPTED` to `reciprocator`** and sends
an empty prompt so the game actually installs the scripted seat (any
non-empty prompt is an LLM seat and `scripted` is ignored). Reciprocator
is the compounding ledger-chain: partner = max net>0, return
`gaveYouLastRound+1` beams, meet only at held>=8 else collect-and-snipe,
seed-gift the nearest unopened cog at held>=2, consume `end` at held>=10
or last round. `PLAYER_SCRIPTED=""` fields the v1 operator prompt as an
LLM seat. LLM seats need `--secret-env USE_BEDROCK=true`.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Two-partner hedging: split gifts between the two best reciprocators so
  one defection doesn't strand the round; compare vs single-partner
  loyalty across an XP batch.
- Loop cadence math: with 4 ticks per beam and 10 max per round, work out
  the optimal gift number per round for a stable pair (send everything
  vs keep half as insurance) and hard-code it.
- Reciprocator farming: the default seat beams back plus one — open every
  episode by beaming each neighbour once and lock onto whoever returns,
  exploiting the published baseline's guaranteed reciprocity.
- Level hygiene: explicitly stop collecting raw once holding 6+ refined
  so beams send supers; measure whether super loops actually close before
  round 12.
- Defection detector tuning: bankedLastRound right after receiving is the
  strongest tell — try cutting off after one strike vs two.
- Cap-aware gifting: a beam over the target's 15-per-level cap is lost —
  when a partner has banked nothing for rounds, assume they are near cap
  and pause gifts until their bank shows on the tape.
- Endgame consume timing: consume "now" every round from round 10 vs
  holding to auto-bank; the 10-tick cash-out cooldown may make small
  frequent banks safer against evade-griefers.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Field the published scripted `reciprocator` instead of the LLM prompt. Leader policies are named ledger-chain; that is this algorithm. Score is tokens consumed; the sim's own gate is reciprocators outscore hoarders ~1.4-1.9x and a leech finishes below the mean. Reciprocator has `gaveYouLastRound` (tokens, not beams) which the LLM observation omits; our v1 prompt also gets kernel facts wrong (consume `now` fires before beams and empties the hand, `meet` parks idle so held<8 wastes the round, last-two-rounds stop, return counted in beams). | default PLAYER_SCRIPTED to `reciprocator` and send empty prompt so drainRegistrations installs the scripted seat (env still overrides; PLAYER_SCRIPTED="" forces the prompt) | | | |
