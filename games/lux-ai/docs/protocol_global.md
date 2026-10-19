The spectator websocket is ws://<host>:<port>/global (player credentials 403).
It carries the bitworld sprite protocol: the baked island as one sprite, per-cell
resource / road / city objects, one chip object per unit, and the broadcast
chrome JSON on the LABEL of reserved sprite id 4090.

The state JSON, one object per presentation frame, identical live and in replay,
is the only thing the renderer reads. Inherited keys: t, mt, ph, lob, sp, mx, st,
lp, sk, ff, en, mm, bs, teams, roster, events, lead, lulls, beats. lux-ai adds
turn, turns, cycle, cycles, night, nightTurn, nightTurns, dayLength, size, res,
coalAt, uraniumAt, terrain (delta: [{i,k,a}]), roads (delta: [{i,l}]), cities
([{id,seat,fuel,upkeep,tiles}]), units ([{u,seat,k,i,w,c,r,cd}]), score and dir.
roster[].name is the seat's REAL policy name (spectator side only);
roster[].alias is the anonymous in-game name a seat itself sees.

Eleven derived event kinds: phase, dawn, dusk, citybuilt, citylost, unitbuilt,
unitlost, research, depleted, directive, end.

Four scrubber beat kinds, all bounded by construction: dusk (<=9), research
(<=4), citylost (throttled to one per seat per night, <=18) and end (1) — at
most 32 markers on a 360-turn scrubber, each a labelled clickable button.

Replay records: `register`, `directive`, `fallback`, `budget_guard`, `stop` and
`result` as chat records; the 13 structured directive bytes, the game start and
the wall-clock stop as INPUT records, which are load-bearing and re-applied
before the turn they belong to is stepped.