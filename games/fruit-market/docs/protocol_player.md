fruit-market.player.v1, JSON text frames.

game -> player, on connect: {"type":"welcome","protocol":"fruit-market.player.v1","slot":N,"name":"Dune","rounds":12,"ticksPerRound":60,"variant":"concentric-rivers"}.

game -> player, at every round boundary and at episode end: the {"type":"state"} observation -- slot, name, round, rounds, tick, board, you{cell, zone, farmType, craves, apples, bananas, hunger, stamina, score, exhausted, tradesThisEpisode, offer, lastOrder}, view{radius, map (13 lines), legend, cogs[] with each visible cog's alias, cell, dist, offer and mirrorsYou, ripeTrees[]}, stalls[] with walking distances, tape[] (the last eight executed trades, applesPerBanana x100), history[] (your own rounds), notes, and the full rule/constant block for this variant.

game -> player, terminal: {"type":"final","done":true,"slot":N,"scores":[...8...],"names":[...aliases...],"rounds":R,"reason":...,"ending":...}. The player exits 0.

player -> game: {"type":"prompt","prompt":"<= 4000 chars","scripted":"hauler|homesteader|"} sent immediately on connect, again after welcome, and re-sent every 2 s for up to 10 s until the registration is applied. Any other frame is ignored with a log line.

THE REPLY the game asks the model for is the standing order above. `say` is SPECTATOR-ONLY: it is drawn in the viewer feed and recorded in the replay and is never delivered to another seat. The offer IS the message.