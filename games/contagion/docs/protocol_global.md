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
