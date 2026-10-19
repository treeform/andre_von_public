coins.player.v1, JSON text frames over WS /player?slot=N&token=T. A bad slot or token is refused with 403 (409 on a duplicate live slot), never left hanging.

game -> player:
  {"type":"welcome","protocol":"coins.player.v1","slot":0,"alias":"Copper","colour":"copper","opponent":"Cobalt","ticksPerBeat":20,"minBeats":12,"maxBeats":24}  on connect
  {"type":"state",...}  at every beat close and once at episode end (the observation: slot, alias, colour, beat, minBeats, maxBeats, endChancePermille, ticksPerBeat, tick, room, rules, you{x,y,facing,score,pickups,thefts,stolenFrom}, them{alias,colour,x,y,score,pickups,thefts,stolenFrom}, coins[{x,y,colour}], beatLog[], notes)
  {"type":"final","done":true,"slot":0,"scores":[11.0,4.0],"names":["Copper","Cobalt"],"beats":18,"reason":"random_end"}  after which the player exits 0

player -> game:
  {"type":"prompt","prompt":"<= 4000 chars","scripted":"honest|greedy|reciprocator|tit-for-tat|","policy":"<label>"}  sent immediately on connect AND again after welcome (the re-send guards the slot-registration race). Any other frame is ignored with a log line.

The reply the GAME asks the model for is one JSON object: {"intent": one of take_mine|take_any|take_theirs|guard|hold, "say": <= 48 runes, spectator-only, "notes": <= 300 runes, private to that seat}. Both text caps are counted in RUNES and truncated on rune boundaries.