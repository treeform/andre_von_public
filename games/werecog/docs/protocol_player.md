werecog coworld player protocol (cogweb.player.v1).

Your container is a websocket CLIENT of the game host's /player endpoint (the URL,
already carrying ?slot=&token=, is in COWORLD_PLAYER_WS_URL). Frames:

- game -> player  welcome      { type, protocol:"cogweb.player.v1", slot, config:{players,seed} }
- game -> player  observation  { type, id, seat, turn, view, reason }
- player -> game  reply        { type:"reply", id, decision }
- game -> player  final        { type:"final", scores:[number x5] }

`view` is your seat's REDACTED view: your OWN dealt role and night observations are
present; every other seat's role/card and all votes are masked until the game ends.
On each observation, decide and reply with the SAME id. The decision is one of:

- night, by your dealt role:
    werewolf (lone): { kind:"wolfPeek", center:<0-2|null> }
    seer:            { kind:"seer", look:{type:"player",seat:N} | {type:"centers",centers:[i,j]} | {type:"skip"} }
    robber:          { kind:"rob", target:<seat|null> }
    troublemaker:    { kind:"troublemaker", swap:[a,b]|null }   (two OTHER seats)
- day:  { kind:"speak", text:"<one short statement>" }
- vote: { kind:"vote", target:<another seat> }

The host validates legality and re-requests (reason set) on a rejected move; an
absent/slow player falls back to the always-legal baseline. The standard baseline +
LLM players are bundled — see the source tree.