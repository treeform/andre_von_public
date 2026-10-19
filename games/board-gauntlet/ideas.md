# Board Gauntlet — Volga Svyatoslavich

Policy: **Volga Svyatoslavich** (`volga`) — shapeshifter who masters every form — every board game.

Coworld: `cow_dbadce13-6ad8-440d-a054-122e326af949` (coworld name `board-gauntlet`)

Board Gauntlet is a rotating perfect-information ladder for two LLM-piloted cogs. Every episode plays ONE of four classic boards - Connect Four (7 files x 6 ranks), Breakthrough (6x6), Hex (7x7) or Quoridor (9x9 with ten walls a side) - drawn deterministically from the episode seed as RotationOrder[seed mod 4] and ANNOUNCED to both seats before their first move, so a policy that only knows one opening book scores in one episode of four. Nothing is hidden: both seats are given the whole board, the whole move history, both position heuristics and the complete legal-move set every ply; the only thing either cannot see is what the other is thinking. Seats alternate strictly, one move each, and the game is zero-sum: +1 for a win, 0 for a draw, -1 for a loss, and the array always sums to zero. Seats play under anonymous cog aliases so no policy can be recognised at the board. The game is LLM-driven: the server sends the acting seat's policy prompt plus its whole observation to Claude, so A POLICY IS JUST A PROMPT - field one by reusing the published player runnable and setting the PLAYER_PROMPT environment variable to your strategy. Two scripted baselines, `tactician` (wins now, blocks an immediate loss, then maximises the position differential) and `hustler` (never defends, maximises its own progress), play any seat that registers as scripted - and every seat when no LLM credentials are available, so episodes always complete.

## Leagues

- `league_e96d74f3-745a-4308-86cf-0ed6489300e5` — Board Gauntlet

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `board-gauntlet-player` — Board Gauntlet Prompt Player: The reference Board Gauntlet policy: delivers its PLAYER_PROMPT (or a default play-to-win strategy) to the game and spectates until the final frame. Every decision is made server-side by Claude from that prompt plus the seat's whole observation. Field your own policy by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/board-gauntlet-player`)
- `board-gauntlet-scripted` — Board Gauntlet Tactician: The scripted tactician baseline as a fieldable policy: wins on the spot when it can, refuses moves that hand the opponent an immediate win, and otherwise maximises the position differential. It registers its seat as rule-based so the game server plays it deterministically, no LLM involved. Set PLAYER_SCRIPTED=hustler for the other baseline, which never defends. (run: `/bin/board-gauntlet-player`)

## Baseline

- Default example: `board-gauntlet-player` — delivers `PLAYER_PROMPT` (or a
  stock play-to-win strategy) and spectates.
- Strongest example: `board-gauntlet-scripted` (`PLAYER_SCRIPTED=tactician`)
  — wins on the spot, refuses moves that hand an immediate win, else
  maximises the standing differential (`hustler` never defends and is weaker).
- Ours: **Volga Svyatoslavich** — fields the server-side `tactician`
  baseline (win now, refuse handing an immediate win, else maximise
  standing differential). The player protocol is prompt-only (no board,
  no move replies), so this is the strongest available seat and matches
  the leaders' `deterministic-tactician` policies. `PLAYER_SCRIPTED`
  still overrides (`hustler`, or empty for the LLM prompt).
- Upload secret-envs: none for the default scripted seat. LLM override
  needs `--secret-env USE_BEDROCK=true`.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Two-ply verbal search: ask for explicit best-reply-to-my-best-reply reasoning in the note before choosing.
- Quoridor wall budget curve: spend the first wall only after the opponent is within 4 steps of goal; compare to current lengthen-by-2 rule.
- Hex swap-less first-move book: exact best openings for 7x7 as seat 0 and the strongest replies as seat 1.
- Breakthrough column-count rule: never advance where attackers <= defenders on the target file; quantify vs current phrasing.
- Connect-four odd/even threat accounting: spell out parity by seat (seat 0 wants odd-rank threats) with an example.
- Anti-hustler clause: when the opponent never blocks, switch to fastest forced win line rather than standing maximisation.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | field server-side tactician (drop LLM prompt) | default PLAYER_SCRIPTED=tactician so the game server plays win/block/standing-diff, no Claude | | | |
