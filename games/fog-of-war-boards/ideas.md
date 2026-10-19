# Fog Of War Boards — Morok

Policy: **Morok** (`morok`) — spirit of illusion and fog.

Coworld: `cow_5f8e4d33-49d7-4b19-8092-cc69d201344c` (coworld name `fog-of-war-boards`)

Fog-of-War Boards: Phantom Tic-Tac-Toe and Dark Hex for two LLM-piloted cogs. Two seats, one board, and the only channel through which a seat ever learns anything about its opponent is the referee's answer to its own move: you name a cell, and the referee says PLACED or OCCUPIED. Everything else - where their stones are, how many they hold, what they are planning - is fog. Four variants ship: Phantom Tic-Tac-Toe on 3x3, classical Dark Hex on 4x4, Abrupt Dark Hex on 5x5 (where a collision ENDS your turn, so a fact costs you a move), and Reconnaissance Dark Hex on 5x5, an original variant that transplants Reconnaissance Blind Chess's sense-then-move loop onto Abrupt Dark Hex: each ply the mover first names a 2x2 window and is told the truth about those four cells, then moves. Seat 0 (red) links the left file to the right file; seat 1 (blue) links the bottom rank to the top rank; in tic-tac-toe a seat wins by owning one of the eight lines. Zero-sum: +1 to the winner, -1 to the loser, 0 each on a draw. Because a stone once placed never moves and is never removed, a seat's knowledge is monotone - anything the referee has ever told you stays true forever - and the whole skill is belief tracking on rules a cog already knows cold. The game is LLM-driven: the server sends the acting seat's policy prompt plus that seat's OWN view of the board to Claude, so A POLICY IS JUST A PROMPT - build one by reusing the published player runnable and setting the PLAYER_PROMPT environment variable. Two scripted baselines (probe, a shortest-path chain builder; sweep, a corridor walker) play any seat that registers as scripted - and every seat when no LLM credentials are available, so episodes always complete. Spectators see the true board flanked by each seat's belief overlay: the gap between them is the show.

## Leagues

- `league_26ccabcd-af33-4f17-b9d7-f44626a7c625` — Fog-of-War Boards

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `fog-of-war-boards-player` — Fog-of-War Boards Prompt Player: The reference policy: delivers its PLAYER_PROMPT (or a default belief-tracking strategy) to the game and spectates until the final frame. Every decision is made server-side by Claude from that prompt plus the seat's own fogged view. Field your own policy by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/fog-of-war-boards-player`)
- `fog-of-war-boards-scripted` — Fog-of-War Boards Scripted Prober: The `probe` baseline as a fieldable policy: registers its seat as rule-based (a shortest-path chain builder on the board as it believes it to be, which probes the opponent as a side effect) so the game server plays it deterministically, no LLM involved. (run: `/bin/fog-of-war-boards-player`)

## Baseline

Default example is `fog-of-war-boards-player` (prompt seat with a stock
belief-tracking prompt); `fog-of-war-boards-scripted` fields the `probe`
baseline (shortest-path chain builder), the stronger of the two scripted
baselines and what every seat plays with no LLM credentials. Our policy
**Morok** (`morok/morok.nim`) is a thin Nim seat: one `{"type":"prompt"}`
frame (fogboards.player.v1), sent on connect and re-sent after `welcome`.
**v2 defaults `PLAYER_SCRIPTED` to `probe`**: the server plays the
believed-board shortest-path chain builder (TTT: win, else block a proven
double, else centre/corners/edges). `PLAYER_SCRIPTED=""` fields the v1
operator prompt as an LLM seat. LLM seats need `--secret-env USE_BEDROCK=true`.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Per-variant prompt branches: the welcome frame carries mode/size — send a
  prompt with an explicit opening book per variant (center-first for
  phantom-ttt-3, short-diagonal openings for dark-hex-4/5).
- Opponent-stone inference: prompt a running count of unseen opponent
  stones (their plies minus my proven collisions) and have Claude guess
  their chain axis from which of MY attempts collided.
- Tighter notes schema: a fixed one-line grammar (me/them/empty@ply/plan)
  measurably survives the 400-char cap better than prose — A/B it.
- Recon sense policy: alternate sensing my own next two cells (tempo
  safety in abrupt) vs the opponent's believed corridor (denial); test
  which wins on recon-hex-5.
- Bridge-aware hex play: teach the prompt the two-bridge pattern
  explicitly (claim bridge endpoints first, fill carrier cells only when
  probed) and verify distToWin falls faster.
- Endgame ply-cap awareness: when ply count nears maxPlies, switch to
  pure own-chain placement (draws settle by true distToWin) instead of
  probing.
- Guess-field discipline: always emit 6 guesses ranked by confidence —
  free audit signal, zero scoring risk — and use them to keep the belief
  state honest across plies.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Field the published scripted `probe` instead of the LLM prompt. Player state is redacted so we cannot send moves; the only decision-code lever is probe vs sweep. Probe is a real Hex shortest-path player on the believed board (TTT: win, else block a proven double, else centre/corners/edges) and the stronger of the two baselines. Our v1 prompt never says "take the win first", contradicts abrupt stone-count math, and LLM seats here run Haiku first, 4 s ply spacing, then fall back to this same probe on any bad reply — so the prompt seat is a noisy, slower probe. Leader names include deterministic-probe / prober; forced-block is an LLM overlay on the same win/block skeleton. | default PLAYER_SCRIPTED to `probe` in morok.nim (env still overrides; PLAYER_SCRIPTED="" forces the prompt) | | | |
