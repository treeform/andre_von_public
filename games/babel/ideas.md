# Babel — Gamayun

Policy: **Gamayun** (`gamayun`) — prophetic talking bird — language.

Coworld: `cow_4985bf14-cb40-4040-9028-e7da74cba677` (coworld name `babel`)

Babel: an emergent-language referential game for four LLM-piloted cogs. A 16-glyph alphabet that means nothing, and 24 rounds to make it mean something. Every round the four seats split into two pairs, each with a SPEAKER and a LISTENER (partners and roles rotate so every ordered relation occurs once per six rounds). The speaker sees a target scene - a shape (circle, square, triangle, star), a colour (red, blue, green, yellow), and a count (1-4) - and sends a message of 1 to 8 glyphs. The listener sees the message and a lineup of four scenes (the target, a near miss, a partial match, and a clear miss) and picks one. Both score when the pick is right. Nothing but glyphs crosses between seats, and every seat sees the 16 tokens under its own seeded symbols in its own order, so no convention can be agreed in advance: meaning has to be grounded in-episode from feedback. Each seat keeps private notes the server feeds back every round (spectators watch the dictionaries form). Seats play under anonymous cog aliases. The game is LLM-driven: the server sends the acting seat's policy prompt plus its alphabet, notes, history, and the target or the message and lineup to Claude, so A POLICY IS JUST A PROMPT - build one by reusing the published player runnable and setting the PLAYER_PROMPT environment variable to your strategy. A built-in code-and-decode baseline plays any seat that registers as scripted - and every seat when no LLM credentials are available, so episodes always complete.

## Leagues

- `league_6ae669f0-5e32-4efd-b363-76bd7f44b240` — Babel

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `babel-player` — Babel Prompt Player: The reference Babel policy: delivers its PLAYER_PROMPT (or a default compositional-code strategy) to the game and spectates until the final frame. Field your own policy by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/babel-player`)
- `babel-coder` — Babel Scripted Coder: The scripted code-and-decode baseline as a fieldable policy: registers its seat as rule-based (a fixed shape/colour/count token code as speaker, a count-based association decoder as listener) so the game server plays it deterministically, no LLM involved. (run: `/bin/babel-player`)

## Baseline

- Default example: `babel-player` — delivers `PLAYER_PROMPT` (or a stock
  compositional-code strategy) and spectates.
- Strongest example: `babel-coder` (`PLAYER_SCRIPTED=1`) — fixed three-token
  shape/colour/count code as speaker, count-based association decoder as
  listener; deterministic, the convention partner every prompt must adapt to.
- Ours: **Gamayun** — a prompt seat. Speaker commits round 1 to a fixed
  positional code (own-alphabet glyphs 1-4 shapes, 5-8 colours, 9-12 counts,
  always 3 glyphs in shape/colour/count order). Listener tries that same
  table first (alphabet listing is token-id order, so it matches the
  scripted baseline from round 1) and only then falls back to a per-partner
  dictionary in notes (CONF/hypothesis marks).
  `PLAYER_PROMPT` / `PLAYER_SCRIPTED` overrides supported (scripted is a bool
  in this protocol).
- Upload secret-envs: `USE_BEDROCK=true` (else the seat silently plays
  scripted).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Message-length signalling: encode count as message LENGTH (1-4 glyphs) freeing glyph slots for shape+colour redundancy.
- Redundant 4th glyph: repeat the attribute that distinguished target from near miss last time this partner erred.
- Notes schema experiment: table form (partner,glyph,meaning,conf) vs prose - measure decode accuracy as listener.
- Anti-baseline clause: detect the scripted coder (identical 3-token messages for identical attributes) and hard-commit to its inferred mapping after 2 confirmations.
- Listener tie-break flip: prefer the near miss outright when dictionary coverage < 2 attributes (vs current caution).
- Speaker echo: after a failed round, resend the SAME message next time the same target recurs rather than reforming the code.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| - | fleet/triage candidate v2 | see git history | triage batch | paired vs champion | REVERT: 0.68->0.64 t=-0.8 4/10 |
| 1 | listener shared-code prior | decode with own alphabet-order table first (listing is token-id order = scripted baseline); per-partner dict only on miss |  |  |  |
