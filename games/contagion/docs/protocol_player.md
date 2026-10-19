# Contagion protocols

## contagion.player.v1 (the player websocket)

A policy is a prompt; the player container's only job is to deliver it. JSON text frames over the
websocket named by COWORLD_PLAYER_WS_URL (already carrying ?slot=N&token=T).

game -> player:

- `{"type":"welcome","protocol":"contagion.player.v1","slot":N,"name":"<region alias>","pos":P,
  "neighbours":["<alias>","<alias>","<alias>"],"weeks":20}` on connect.
- `{"type":"state", ...}` after every event: `week`, `weeks`, `weeksPlayed`, `variant`, your
  `region` and `pos`, the six `regions` and the nine `map` edges, `own` (confirmed, confirmedNew,
  deaths, deathsWeek, gdp, grossGdp, spendWeek broken into spendTesting / spendOwnBorders /
  spendNeighbourBorders, aidIn, aidOut, lockdown, testing, gates with their effective values,
  hospital band as a word, score), `others` (per region: alias, pos, confirmed, confirmedNew,
  deaths, gdp, score, lockdown, testing, gates), `aidLastWeek`, `aidTotals`, `heard`, `notes`,
  `history`, `phase`, `done`, `reason`. This frame is REDACTED: no true infection counts anywhere,
  no other region's hospital band, no other seat's notes, and no policy display names. The prompt
  the server builds for that seat carries exactly this information and no more.
- `{"type":"final","done":true,"scores":[...],"gdp":[...],"deaths":[...],"regions":[...],
  "names":[6 region ALIASES],"weeks":N,"reason":"complete|deadline"}` at the end, after which the
  player should exit.

player -> game:

- `{"type":"prompt","prompt":"<at most 4000 chars>","scripted":"<at most 32 chars>"}`, sent
  immediately on connect and again after `welcome` (the re-send covers the slot-registration race).
  `scripted` of `sentinel` / `1` / `true` / `yes` registers the threshold baseline for that seat,
  `laggard` the leaky one, and `""` means LLM-driven. The reference player reads PLAYER_PROMPT and
  PLAYER_SCRIPTED from its environment.