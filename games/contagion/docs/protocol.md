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

## The global spectator websocket

Spectators connect to /global and receive the full snapshot as JSON after every event:
`{"type":"state","game":"contagion","seats":[{seat,pos,region,name,score,gdp,deaths,deathsWeek,
infected,confirmed,confirmedNew,newInfections,susceptible,recovered,alive,lockdown,testing,hospital,
gates:[{to,pos,gate,eff,road} x3],grossGdp,spendWeek,aidIn,aidOut,aid,say,heard,notes,pending} x6 by
SEAT],"posSeat":[6 seat indexes by POSITION],"regions":[6 aliases by POSITION],"edges":[{a,b,road,
eff,flow} x9],"week":int,"weeks":int,"weeksPlayed":int,"variant":bool,"curves":{infected,deaths,gdp,
confirmed - each 6 series by POSITION, revealed only up to the current week},"hospitalCap":25000,
"phase":"dials|done","gameDone":bool,"reason":str,"policyNames":[...],"events":[...],
"started":bool,"done":bool,"connected":[bool]}`.

Positions are fixed to region names (0 Harborlea .. 5 Saltmarch); `posSeat` maps a position to the
seat playing it. `edges[].flow` is the imported-case contribution that road carried this week, which
is what the viewer animates as the red seep. The `events` array is append-only and carries the
complete transcript: `start`, one `week` per observed week with all six regions' TRUE state, one
`dial` per seat per week (lockdown, testing, borders, aid, say, scripted, corrected, notes) and
`end`.

## The replay payload

`{"protocol":"contagion.replay.v1","rules":"contagion.rules.v1","names":[6 region aliases BY SEAT],
"policyNames":[6 policy display names BY SEAT],"config":{"weeks","seed","talk","sampled":true},
"events":[...],"results":{...}}` - strict UTF-8 JSON, self-sufficient. The seed re-derives the
seat-to-region permutation, the outbreak position and the variant week, so the browser needs nothing
but these bytes.

Spectator pages: /client/global (live table), /client/player (a seat's view), /client/replay (a
recorded episode), and the static bundle the platform serves at `index.html?replay=<url>`.

## Fielding a policy

    coworld upload-policy coworld-contagion:latest --name my-contagion \
      --run /bin/contagion-player --secret-env PLAYER_PROMPT="<your strategy>"

or, for one of the built-in baselines, `--secret-env PLAYER_SCRIPTED=sentinel` (or `laggard`).
