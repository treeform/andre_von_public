# Wire protocol

## The Coworld runtime contract

In: `COGAME_CONFIG_URI`. Out: `COGAME_RESULTS_URI`, `COGAME_SAVE_REPLAY_URI`,
`COGAME_PLAYER_FAILURE_URI`, `COGAME_EVENTS_URI`, `COGAME_METRICS_URI`.
`COGAME_LOAD_REPLAY_URI` + `/client/replay` drive local replay mode.
`COGAME_HOST` / `COGAME_PORT` bind the server.

HTTP: `GET /healthz`, `GET /client/player?slot=&token=` (token-checked, and it
does **not** open the player socket), `GET /client/global`,
`GET /client/replay`, `GET /client/<asset>`, `GET /replay-data`,
`GET /reward`. Websockets: `/player?slot=<i>&token=<t>` (403 on a bad slot or
token, 409 on a duplicate) and `/global`.

## The player socket

A seat sends **one Sprite v1 chat frame** (`0x81`) carrying its registration,
re-sent ten times over the first ten seconds because joins are
slot-sequential:

```json
{"type":"register","policy":"<label, <=48 runes>",
 "prompt":"<PLAYER_PROMPT or empty, <=4000 runes>",
 "scripted":"sprawl"|"crown"|null}
```

A seat that registers with neither field, or never registers, is seated as
`sprawl`. Any OTHER chat text from a seat is dropped: this game has no
inter-seat channel of any kind — no chat, no radio, no `say`, no emote.

The seat then sends the Sprite v1 Ready packet (`0x85`) after each received
frame, which is legitimate here because **a seat sends no inputs**: every
decision is made in the game server, which calls the LLM once every eight
turns with all living seats batched into ONE parallel request.

The game sends the seat:

```json
{"type":"welcome","protocol":"gen-generals-io.player.v1","slot":0,
 "alias":"RED-alpha","turns":240,"directive_every":8}
{"type":"turn","turn":96,"of":240,"you":"RED-alpha","alive":true}
{"done":true,"result":{...the results document...}}
```

A seat frame carries **nothing a seat may not know**: its own alias, the turn
and whether it is still standing. No board, no rival, and never a real policy
name. An eliminated seat keeps receiving frames and exits 0 with everyone
else — elimination is a game state, not a disconnection.

