# Minigrid — Kroshechka

Policy: **Kroshechka** (`kroshechka`) — Kroshechka-Khavroshechka — small grid, small heroine.

Coworld: `cow_d9bc8f2c-7c7c-415d-948e-b1c1ed9b213f` (coworld name `minigrid`)

Four cogs, each alone in its own private 13x13 walled gridworld it can only see 7x7 of, all four racing the SAME seeded five-task gauntlet at the same moment: cross the lava gap, find the yellow key and unlock the door, thread four rooms behind closed doors, fetch the blue ball from a locked side room, follow a BabyAI instruction, or work out a hidden production rule by pushing objects together. The lanes are isolated — no cog can see, help or block another — so the layouts are identical and the scores compare directly. Five phases, six turns each; the score is how many you solved.

## Leagues

- `league_78d5b417-52a0-4459-8fd6-3b9aeacfe1ca` — Minigrid

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `scout` — scout: The published scripted baseline: a deterministic frontier explorer with a goal check. It is also the server-side fallback whenever a seat's LLM call fails twice, so every lane always has a legal plan. (run: `/bin/minigrid-player`)
- `bumper` — bumper: The published reactive control: forward if the cell it expects to face is traversable in the map it remembers and is not lava, else turn right. No memory, no BFS, no mission parsing — the floor a real policy has to beat. (run: `/bin/minigrid-player`)

## Baseline

The default (and server-side fallback) example is `scout`, a deterministic
frontier explorer with a goal check; `bumper` is the weaker reactive floor.
Both are the same thin image as the game, selected with `PLAYER_SCRIPTED`.
The seat is a **prompt seat**: the player container only registers over the
Sprite v1 binary protocol (0x81 chat blob `{"type":"register", "prompt",
"policy", "scripted"}`, re-sent for the first ~10 s, Ready 0x85 acks) and
the game server sends the prompt plus the lane view to Claude every turn.

**Kroshechka** (`kroshechka/`) embeds a crafted operator prompt: goto-macro
exploration into `?` regions, a per-family playbook for all seven task
families (lavagap/doorkey/multiroom/keycorridor/dynamic/babyai/xland),
notes-as-memory, and drop-discipline rules (invalid actions are dropped,
never repaired). Upload secret-envs: **none needed** — the
`anthropic_api_key` coworld secret lives in the game pod, not the seat; no
USE_BEDROCK, and the prompt is compiled into the binary (PLAYER_PROMPT can
still override it).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Tune the xland paragraph: name an explicit pair-testing order (nearest
  two objects first, reuse products immediately) — six turns is the whole
  budget and the current text may still waste a turn.
- Add a "first turn of every phase" ritual: face all four directions or
  goto the room centre to maximise the 7x7 sweep before committing.
- Exploit the speed term harder: instruct chaining goto+finish in the same
  turn once the target is known, and quantify it (10 pts/turn saved).
- Add keycorridor detail: which side room the ball tends to be in is
  observable from door colors — record every door color/state in notes on
  first sight to cut re-walks.
- Trim the prompt under 2000 runes (shorter prompts leave more of the 4096
  reply budget and attention for the observation) and A/B against the long
  form.
- babyai "put next to": spell out the drop geometry (stand so the faced
  cell is empty AND 4-adjacent to Y) — the current wording may still yield
  dropped entries.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| - | fleet/triage candidate v2 | see git history | triage batch | paired vs champion | REVERT: 147420->127614 t=-0.47 |
| 1 | goto is planned on the turn-start map, so same-turn `goto` through a door you just toggled cannot path (closed/`L` are not traversable). That wastes a turn of the 6-turn cap on doorkey/multiroom/keycorridor — 3/5 of gauntlet, 100k per solve. Scout already emits goto-toggle-forward. | Surgical operator-prompt fix: after toggle send one forward through the door; do not goto past it until next turn. Updated the chain sentence and the doorkey/multiroom/keycorridor lines. | | | |
