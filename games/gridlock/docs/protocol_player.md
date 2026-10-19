gridlock.player.v1 - JSON text frames over the websocket named by COWORLD_PLAYER_WS_URL (already carrying ?slot=N&token=T). A gridlock policy is a prompt: the player container's only job is to deliver it, and the game server makes every decision by sending that prompt plus the seat's view to the model once per routing turn.

player -> game, exactly once on connect:
  {"type":"register","prompt":"<strategy text>","scripted":null|"dispatcher"|"beeline","policy":"<label, <=48 runes>"}
  prompt is truncated at 4000 runes, never rejected, and is never written to the replay or the results. A seat that never registers, or registers with neither field, plays the dispatcher baseline; a no-show never ends the episode.

game -> player:
  {"type":"welcome","protocol":"gridlock.player.v1","slot":N,"fleet":"Carbon","colour":"#e07a3f","turns":20,"turn_seconds":10}
  {"type":"turn","turn":7,"tick":1680,"fleet":"Carbon","view":{...},"plan_source":"llm"} once per routing turn (informational; the seat is not required to answer)
  {"done":true,"result":{...the results document...}} then close.

The view carries: turn/of/tick/ticks_left/seconds_left; you.{fleet,colour,depot,depot_district,vans,docked,loading,waiting_dispatch,on_road_loaded,on_road_empty,stalled,delivered,delivered_last_turn,backlog,mean_trip_seconds,stalled_pct,last_plan,next_orders[<=6]}; city.{grid,districts,lane_cells,arterial_cols,arterial_rows,signal,discharge_per_green_step,jam_index,districts_heat[3 strings of 3 digits],hot_lanes[<=8, worst first]}; the PUBLIC fleets[] block of every fleet's delivered and on_road counts in fixed alias order; and events_last_turn.

Hidden from a seat: the per-fleet composition of any lane's queue, every rival's plan, note, say, prompt, policy kind, destinations, backlog and trip times, individual rival van positions, the canonical destination schedule beyond its own next six orders, the seat-to-depot permutation for any other seat, the episode seed, and the future. The only names in a view are the depot aliases Carbon / Oxygen / Germanium / Silicon, re-permuted every episode.

The routing plan the model returns: {"congestion_weight":0-100,"patience":0-100,"dispatch":0-100,"spread":0-100,"corridor":[bx,by]|null,"avoid":[bx,by]|null,"priority":"near"|"far"|"fifo","note":"<=140 runes","say":"<=32 runes"}. Parsing is tolerant (fences stripped, outermost balanced object taken, numeric strings and "70%" accepted, district names accepted); every field is repaired and clamped, one retry is issued, and a second failure falls back to the dispatcher plan with a fallback event. Strings are truncated on RUNE boundaries.