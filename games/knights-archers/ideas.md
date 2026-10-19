# Knights Archers — Dobrynya Nikitich

Policy: **Dobrynya Nikitich** (`dobrynya`) — the knight bogatyr.

Coworld: `cow_23e4f026-6724-4b80-bb34-dcd02c214ee2` (coworld name `knights-archers`)

Four-seat cooperative horde defence. Two knights and two archers hold one gate against a marching horde of the dead; one breach, or one hero death, ends the wave for everybody. A policy is a prompt.

## Leagues

- `league_362e5211-3bdc-40f4-968e-c00c8f812bfe` — Knights-Archers

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `baseline` — Phalanx Baseline: Scripted hero: knights intercept the two leading zombies, archers focus-fire and back off when anything gets close. (run: `/bin/knights-archers-player`)

## Baseline

Default example: `baseline` (phalanx — the certification player, the
per-turn fallback, and the driver of any seat that never registers);
`stand` is the weaker foil. Our `dobrynya` is the Sprite v1 thin player in
Nim: registration re-sent over the first ~10 s of frames (joins are
slot-sequential), a ready packet after every frame, no inputs ever.
**Default is `PLAYER_SCRIPTED=phalanx`** (empty prompt so the server's
`isLlm = prompt.len > 0` actually honours the baseline). Empty
`PLAYER_SCRIPTED` restores the operator prompt (warden line + volley
focus). Env still overrides (`phalanx` | `stand` | empty). Upload
secret-envs: none for the phalanx default. LLM override needs
`--secret-env USE_BEDROCK=true`. Sim checked at coworld 0.1.3 /
`4f7488f5aca5c4364abf8e51a14cb34148fc5d49`.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- XP the prompt seated with three `phalanx` teammates — the league seats unknown partners, so the prompt must slot into phalanx's target-division without duplicating its assignments.
- Volley discipline test: both-archers-same-target vs phalanx's split (leader + third) when partners are also LLMs — measure wave-clear rate, not kills.
- Tune the knight chase line: x=820 vs 700 vs "never east of the front archer" — casualties near the breach are the main wave-ender.
- say-protocol experiment: fixed vocabulary ("north"/"south"/"leader") vs free text — check whether partner LLMs actually read and divide lanes.
- Late-wave safety margin: switch to pure hold/fall_back at 12 s remaining vs 6 s — how many banked clears does caution buy vs kills lost?
- Screen intent trial: knights `screen` the leader while archers volley it, instead of intercept — does standing 120 px in front leak fewer chargers?

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Field built-in `phalanx` instead of the LLM prompt. Leader is `co-gas-knights-archers-phalanx-relhalpha` (wr 0.94); richard also fields phalanx. Score is shared: kills + 20*cleared, cap 180, win at 90. One casualty or breach ends the wave for everybody. Server sets `isLlm` from `prompt.len > 0` (src/kaz/server.nim), so our compiled defaultPrompt made every upload an LLM seat. Phalanx is the grid-tuned work-splitter (K-alpha z[0], K-beta z[1], A-alpha z[0], A-beta z[2]; 493 team value vs stand 339). The LLM prompt was factually wrong for mixed partners: `intercept` always goes to the leader (y-lanes stack both knights), and both-archers-same-target duplicates phalanx A-alpha. Scripted/code A/Bs have won; prompt rewrites have lost. | default PLAYER_SCRIPTED to `phalanx` and send an empty prompt while a baseline is named (env still overrides; empty PLAYER_SCRIPTED restores the operator prompt) | | | |
