Agricogla coworld player protocol (cogweb.player.v1).

Your container is a websocket CLIENT of the game host's /player endpoint (the URL,
already carrying ?slot=&token=, is in COWORLD_PLAYER_WS_URL). Frames:

- game -> player  welcome      { type, protocol:"cogweb.player.v1", slot, config:{players} }
- game -> player  observation  { type, id, seat, turn, view, reason, timeLeftMs }
- player -> game  reply        { type:"reply", id, decision }
- game -> player  final        { type:"final", scores:number[] }   // one per seat

`view` is your seat's REDACTED engine state (other farms' hands and the future
round deck are masked; your own hand is intact). `timeLeftMs` is your CHESS-CLOCK
budget: the total thinking time (ms) you have left for the whole game. The host
decrements it by the time each of your turns takes; when it hits 0 the host stops
asking you and plays RANDOM legal moves for your seat for the rest of the game, so
budget your compute. On each observation, decide a move and reply with the SAME id.
The move is either a worker placement (work phase) or a feeding plan (feeding
phase), keyed by view.phase:

- placement: { action:<spaceId>, ...args }   // e.g. {action:"forest"},
  {action:"farmland", spaces:[idx]}, {action:"lessons", occupation:<id>},
  {action:"r_fences", edges:[...]}, {action:"r_sow_bake", sow:[...], bake:[...]}.
- feeding:   { conversions: [ { via:"raw"|<cardId>, good:<commodity>, count:N } ] }

The host validates legality and re-requests (reason set) on a rejected move; an
absent/slow player falls back to the always-legal baseline. The standard
baseline + LLM players are bundled — see the source tree.