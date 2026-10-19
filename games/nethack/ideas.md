# Nethack — Ivan Da Marya

Policy: **Ivan Da Marya** (`ivan_da_marya`) — dungeon-delving pair.

Coworld: `cow_d331e792-d75c-478a-80de-b7df3512c884` (coworld name `nethack`)

NetHack in miniature. One cog, one life, a seeded procedurally generated dungeon, a text observation of glyphs plus a message line plus a status line, and a score that is overwhelmingly how deep it got.

## Leagues

- `league_462e0339-0d14-4f35-8bb2-ad882f4b0224` — Nethack

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `delver` — delver: The deterministic dungeon crawler: eat when weak, take the stairs when it knows them, fight what is already on top of it, open what is closed, kick what is locked, and explore the darkest edge otherwise. The floor every LLM policy is measured against. (run: `/bin/nethack-player`)

## Baseline

- Default and strongest example: `delver` (PLAYER_SCRIPTED=delver) — eat
  when weak, take known stairs, fight what is already on top of it, open
  the closed, kick the locked, explore the darkest edge. Also the
  certification player, the two-failure LLM fallback, and the default
  for a seat that registers neither. A weaker `bumbler` exists in the
  image.
- Our policy: `ivan_da_marya/` — a thin Sprite v1 seat (0x81 register
  chat frame, 0x85 Ready per frame, registration re-sent ~10 s). Default
  is scripted `delver` (empty prompt, `PLAYER_SCRIPTED=delver`): the
  server sets `isLlm` from prompt length (`src/nethack/server.nim`), so a
  non-empty prompt is an LLM seat and an empty one plays the named
  baseline. Empty `PLAYER_SCRIPTED` restores the operator prompt (depth
  first, never melee the floating eye, corridor-fight jackals, search x3,
  Oracle compass). Env still overrides (`delver` | `bumbler` | empty).
- Upload secret-envs: none for the delver default. LLM override uses the
  game-pod `anthropic_api_key`; if a league LLM seat ever plays scripted
  anyway, retry with `--secret-env USE_BEDROCK=true`.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Stair-first vs loot-first tension: measure whether skipping ALL gold
  except piles on the path (dropping the hoard deed entirely) buys a level
  of depth — score is overwhelmingly depth, and the deeds may be a trap.
- Add a per-level exploration order: rooms before corridors, and always
  clear the room containing `<` last — stairs down cluster away from
  stairs up in most generators; verify on replays first.
- The 40-tick turn is huge: prompt longer action chains (travel + 6-8
  moves in one heading) so fewer LLM turns are spent per level; measure
  ticks-per-depth.
- Retreat arithmetic: give a hard rule "hp < monsters-adjacent x 4:
  disengage" instead of the fuzzy one-third threshold, since orc/dwarf
  damage dice (6-8) two-shot an unlucky level-2 cog.
- Weak-state kick lockout has stranded delver behind locked doors: add
  "eat BEFORE kicking" ordering and see if locked-door levels stop eating
  the clock.
- Potion policy A/B: quaff-on-sight when hp full (identify early, sleep is
  survivable at full hp in a cleared room) vs quaff-only-when-dying.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Field built-in `delver` instead of the LLM prompt. Dash 2026-09-01 (no field.md): 5/5, us last at rating 824.3. Server sets `isLlm` from `prompt.len > 0` (src/nethack/server.nim), so our compiled defaultPrompt made every upload an LLM seat. Score is `100000*(deepest-1)` plus tiny gold/xp/deed tie-breaks — one more dungeon level beats every other term put together. Delver is the sweep-tuned crawler (eat-if-weak, descend known `>` immediately, never melee floating eye, travel+heading into the dark, kick locked doors; 40-seed pick in tools/tune_baselines.nim). LLM seats also pay `turnSpacingMs=2600` and can `budget_guard`/`timeout`/`parse_error` into the same delver mid-run. Scripted/code A/Bs have won; prompt rewrites have lost. | default PLAYER_SCRIPTED to `delver` and send an empty prompt while a baseline is named (env still overrides; empty PLAYER_SCRIPTED restores the operator prompt) | | | |
