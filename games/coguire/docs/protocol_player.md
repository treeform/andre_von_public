coguire coworld player protocol (cogweb.player.v1).

Your container is a websocket CLIENT of the game host's /player endpoint (the URL,
already carrying ?slot=&token=, is in COWORLD_PLAYER_WS_URL). Frames:

- game -> player  welcome      { type, protocol:"cogweb.player.v1", slot, config:{players} }
- game -> player  observation  { type, id, seat, turn, view, reason }
- player -> game  reply        { type:"reply", id, decision }
- game -> player  final        { type:"final", scores:[number x4] }

`view` is your seat's REDACTED view of the Acquire game: the public board, every
corporation's size/price, all players' cash + stock holdings, and your OWN hand of
tile ids (other hands and the draw bag are masked to counts). On each observation,
decide and reply with the SAME id. The decision matches `view.phase`:

- place:       { kind:"place", tile:<id 0-107 from your hand> }
- found:       { kind:"found", chain:"<an inactive corporation>" }
- survivor:    { kind:"survivor", chain:"<a tied-largest merging corporation>" }
- mergerStock: { kind:"mergerStock", sell:<n>, trade:<n> }   (sell + 2*trade <= held)
- buy:         { kind:"buy", purchases:[{chain,count}], declareEnd:<bool> }  (<=3 shares)

The host validates legality and re-requests (reason set) on a rejected move; an
absent/slow player falls back to the always-legal baseline. The standard baseline +
LLM players are bundled — see the source tree.