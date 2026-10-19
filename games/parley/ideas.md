# Parley — Boyan

Policy: **Boyan** (`boyan`) — the bard-orator of Igor's Tale.

Coworld: `cow_b94883ee-e808-4c8f-a87d-a2c224477ed5` (coworld name `parley`)

Parley: a talkative last-cog-standing party game. Five cogs sit around a table; one holds the paintgun and is IT. Each turn IT says something to the table, then shoots one living cog, choosing its AIM in secret: a head-shot always hits, a hip-shot misses 2 times in 3. A hit costs the target 1 hp; the target takes the gun hit or miss; a knockout (0 hp) leaves the gun with the shooter. The table only ever sees hit or miss, never the aim, so a hip-shot can hand the gun to a friend while probably leaving them unhurt, or fake a grudge. Between shots the other cogs plead, scheme, bluff, and bargain in table-wide chat. CARDS: every round each cog is secretly dealt a FRIEND and an ENEMY (two distinct other cogs; only that cog knows its own cards; spectators see everything; the deal reshuffles every round). Round scoring: 3 points for being last cog standing, 1 point for fatally shooting your enemy, 1 point if your friend is last standing. A match is several rounds (default 3) and round points accumulate into the match result, so grudges and reputations carry across rounds. The game is LLM-driven: the game server sends each seat's table view and its policy prompt to Claude Sonnet every turn, so A POLICY IS JUST A PROMPT - build a policy by reusing the published player runnable and setting the PLAYER_PROMPT environment variable to your table-talk strategy (persuasion, threat assessment, and alliance-breaking are the whole game). Player containers deliver their prompt over the websocket and then spectate; all decisions happen game-side. Without LLM credentials the game degrades to a scripted random-target baseline (head-shots, hip-shot at its own friend) so episodes always complete.

## Leagues

- `league_d5171da5-7f96-4b70-9421-d675b698e160` — Parley

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `parley-player` — Parley Prompt Player: The reference Parley policy: delivers its PLAYER_PROMPT (or a default scheming-table-talk personality) to the game and spectates until the final frame. Field your own policy by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/parley-player`)

## Baseline

Default example: `parley-player` (a prompt seat; the only shape parley
has - no scripted registration field exists, the random-target baseline
only fires game-side when LLM credentials are missing). Our `boyan` is
the thin player rewritten in Nim carrying an operator prompt: never
reveal cards, talk the table into shooting your enemy, head-shot only
for the kill (enemy at 1 hp), hip-shots for deniable gun movement, and
naked-math endgame at three cogs. Supports PLAYER_PROMPT override. LLM
seats need USE_BEDROCK=true at upload.

Sim checked at coworld 0.3.9 /
`da276ebfe1fc2874b42f3f363960c5dd20964eea`: `sampleEpisode` draws rounds
3-20, survivors 1-3, hp 2-5; `scores()` pays 3 to every remaining cog,
1 for a fatal shot on your enemy, 1 if your friend is among the
survivors. League leader `co-gas-parley-adaptive-relhalpha` is named
for that sampled table.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Persona A/B: swap the warm-bard persona for a quiet-analyst persona and compare placements — likeability vs invisibility as shot-deterrent.
- Add an explicit first-round rule: never shoot before anyone else has (the first aggressor becomes the table's villain).
- Tune the hip-vs-head balance: try "head-shot whenever target is not your friend and has 1 hp, hip everything else" against the current mixed rule.
- Gun-handling experiment: forbid handing the gun to the friend entirely (the friend point only pays if they survive; giving them the gun paints a target).
- Add cross-round memory instructions: open each round referencing last round's betrayals to pre-seed coalitions.
- Exploit the miss tell: a miss is 2/3 evidence of a hip-shot, i.e. of an alliance between shooter and target — call it out to break alliances.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | multi-survivor scoring (prompt treated unique last-standing as the 3-pt prize) | scoring line + rule 6: 3 pts to EVERY remaining cog; table ends at 1-3 survivors (infer 1-or-2 if three still live); friend-survive is +1 on top of your 3; at 3 left finish a 1-hp non-friend, never the friend | | | |
