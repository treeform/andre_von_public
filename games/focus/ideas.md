# Focus — Finist Yasny Sokol

Policy: **Finist Yasny Sokol** (`finist`) — the sharp-eyed falcon.

Coworld: `cow_f00c6a5b-0139-4753-9e26-7badd69051fb` (coworld name `focus`)

Focus (Domination): Sid Sackson's stacking board game for two cogs. An 8x8 board with the three squares in each corner missing (52 squares), 18 pieces each. Pieces stack; whoever owns the TOP piece controls the stack. On your turn move the top k pieces of a stack you control exactly k squares orthogonally, landing on whatever is there - or drop a reserve piece anywhere. Stacks taller than five shed pieces from the bottom: your own go to your reserve, enemy pieces are captured for good. A player who cannot move loses; at the ply cap the side with more material (pieces in controlled stacks plus reserve) wins. Seats play under anonymous cog aliases so nobody can meta-game a familiar policy name. The game is LLM-driven: each turn the game server sends the acting seat's policy prompt plus the board and every legal move to Claude, so A POLICY IS JUST A PROMPT - build one by reusing the published player runnable and setting the PLAYER_PROMPT environment variable to your strategy. A built-in minimax baseline plays any seat that registers as scripted - and every seat when no LLM credentials are available, so episodes always complete.

## Leagues

- `league_a27cd3f2-d1ba-4f8a-be5f-93e583affa11` — Focus

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `focus-player` — Focus Prompt Player: The reference Focus policy: delivers its PLAYER_PROMPT (or a default sound-play personality) to the game and spectates until the final frame. Field your own policy by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/focus-player`)
- `focus-tactician` — Focus Scripted Tactician: The scripted baseline as a fieldable policy: registers its seat as rule-based (two-ply minimax on material, captures, and mobility) so the game server plays it deterministically, no LLM involved. (run: `/bin/focus-player`)

## Baseline

Default example is `focus-player` (prompt seat, `/bin/focus-player`); the
strongest scripted baseline is `focus-tactician` (two-ply minimax on
material + captures + mobility), which also fills credential-less seats.
Our policy `finist` is the thin Nim prompt seat:
`{"type":"prompt","prompt","scripted"}` on connect and after welcome, then
listen until `final` — NOTE `scripted` is a BOOL in this protocol, unlike
the other cogame seats. **v2 defaults `PLAYER_SCRIPTED` to true** (env
still overrides; empty / `0` / `false` / `no` restores the v1 operator
prompt). Field leaders are `co-gas-focus-baseline-*`; `decide` plays the
minimax whenever `scripted` is true. Default is scripted, so no Bedrock
flag is required. LLM override needs `--secret-env USE_BEDROCK=true`.
Sim checked at coworld 0.1.3 (Metta-AI/cogame-focus). The unused prompt
is still a move-ordering checklist for LLM A/Bs.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Add a compact worked example to the prompt (one board fragment, the
  k-move arithmetic, one overflow capture computed digit by digit) — move
  legality errors burn retries and LLM board games live and die on
  arithmetic slips.
- Explicit 1-ply blunder check: instruct enumerating, after the chosen
  move, every enemy stack whose height reaches the destination square,
  plus reserve drops; reject the move if the reply loses more material
  than the move gained.
- Anti-minimax opening: the tactician is two-ply and material-greedy —
  bait it with a sacrifice that sets up a two-move overflow recapture it
  cannot see; test head-to-head against the scripted filler.
- Reserve-hoarding variant: never drop before ply 20 unless mated
  otherwise; reserves are both tempo and anti-mate insurance, and early
  drops are the likeliest prompt-induced leak.
- Ply-cap awareness by number: the state carries ply and maxPlies — add a
  rule to compute material lead at every ply past 80% of the cap and
  refuse all stack-height gambles when ahead.
- Table-talk probe: seed one line of needling about the opponent's last
  move; against LLM seats measure whether replies leak plans in the
  public events feed.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Field the published scripted tactician instead of the LLM prompt. Field leaders are `co-gas-focus-baseline-relhalpha` (1113.6, wr 0.55) and `co-gas-focus-baseline-richard` (894.6, wr 0.55); prompt seats trail (`focus-blitz` 0.39, `focus-player` 0.32) and we are last at 833.4. The player wire is prompt-only (no move frames); `decide` short-circuits to two-ply minimax on material/captures/mobility whenever `scripted` is true. Scripted/code A/Bs have won every trial in this repo; prompt rewrites have not. | default PLAYER_SCRIPTED to true in finist.nim (env still overrides; empty/0/false/no restores the operator prompt) |  |  |  |
