gift-refinements.player.v1, JSON text frames over ws://<host>/player?slot=N&token=T.

GAME -> PLAYER
  {"type":"welcome","protocol":"gift-refinements.player.v1","slot":N,"name":"Cyr","rounds":12,"ticksPerRound":60,"variant":"refinery","aliases":["Aro","Bex","Cyr","Dov","Eno","Fay"]} on connect.
  {"type":"state", ...} at every round boundary: slot, name, round/rounds/roundsLeft, tick, board, you{cell,tokens{raw,refined,super},held,rawestLevel,score,beamsPerRound,lastOrder}, cogs[] (alias, slot, cell, dist, hittable, dir, score, youGave, gaveYou, net, lastGaveYouRound, bankedLastRound - never an inventory), loose[], ledger[] (last 16 gifts), banks[] (last 8 consumes), history[], notes, rules{}.
  {"type":"final","done":true,"slot":N,"scores":[...6...],"names":[...aliases...],"rounds":R,"reason":...,"ending":...} at the end, after which the player exits 0.

PLAYER -> GAME
  {"type":"prompt","prompt":"<= 4000 chars","scripted":"reciprocator|hoarder|"} sent immediately on connect, again after welcome, and re-sent every 2 s for up to 10 s until the game acknowledges it (the slot-admission race). Any other frame is ignored with a log line.

The reply schema the game asks the model for is documented on the "Fielding a policy" page. NOTE: `say` is SPECTATOR-ONLY and never reaches another seat - there is no talk channel in this world.