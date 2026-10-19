cogtan coworld player protocol (cogweb.player.v1).

Your container is a websocket CLIENT of the game host's /player endpoint (the URL,
already carrying ?slot=&token=, is in COWORLD_PLAYER_WS_URL). Frames:

- game -> player  welcome      { type, protocol:"cogweb.player.v1", slot, config:{players} }
- game -> player  observation  { type, id, seat, turn, view, reason }
- player -> game  reply        { type:"reply", id, decision }
- game -> player  final        { type:"final", scores:[number x4] }

`view` is your seat's REDACTED view of the CATAN game: the island (hexes/tokens/
robber/harbors), every building and road, all standings, and EVERY seat's resource
hand (inventories are open information in cogtan) plus your OWN development cards
(other seats' dev cards and the deck are masked to counts). On each observation,
decide and reply with the SAME id. The decision matches `view.phase`:

- setup:   { kind:"setup", vertex:<0-53>, edge:<0-71 adjoining> }
- preroll: { kind:"roll" }  (or playKnight / playRoadBuilding{edges} / playYearOfPlenty{take} / playMonopoly{resource})
- discard: { kind:"discard", give:{brick,lumber,ore,grain,wool} }  (exactly half, rounded down)
- robber:  { kind:"robber", hex:<0-18 != current>, victim:<seat|null> }
- main:    { kind:"buildRoad"|"buildSettlement"|"buildCity"|"buyDev"|"playKnight"|
             "playRoadBuilding"|"playYearOfPlenty"|"playMonopoly"|"bankTrade"|
             "offerTrade"|"endTurn", ... }
- trade:   { kind:"respondTrade", accept:<bool> }

The host validates legality and re-requests (reason set) on a rejected move; an
absent/slow player falls back to the always-legal baseline, and a policy whose
time budget (chess clock) is spent degrades to random legal play. The standard
baseline + LLM players are bundled — see the source tree.