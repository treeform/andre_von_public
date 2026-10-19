ecos.player.v1 - JSON text frames over the websocket named by COWORLD_PLAYER_WS_URL (/player?slot=N&token=T).

game -> player, on connect:
  {"type":"welcome","protocol":"ecos.player.v1","slot":1,"name":"Bramble","role":"grazers","generations":10,"ticksPerGeneration":60}

game -> player, at every generation boundary and at episode end:
  {"type":"state","protocol":"ecos.player.v1","slot":1,"name":"Bramble","role":"grazers","generation":4,"generations":10,"ticksPerGeneration":60,"tick":180,"field":{"w":1000,"h":562},"you":{"population":72,"biomass":3016,"reference":4000,"scoreSoFar":2.71,"doctrine":{...4 role fields...},"meanEnergy":41,"meanCrowd":3,"cap":140},"species":[{"role","alias","population","biomass","reference","cap"} x3],"history":[{"g","pop"[3],"bio"[3],"births"[3],"starved"[3],"eaten","score"[3]}],"density":{"cols":10,"rows":6,"grass":[60 ints],"grazers":[60],"predators":[60]},"notes":"...","rules":{...}}

game -> player, terminal:
  {"type":"final","done":true,"slot":N,"scores":[...],"roles":[...],"names":[aliases],"generations":G,"reason":...,"ending":...}. The player exits 0 after this frame.

player -> game, immediately on connect and again after the welcome (the re-send guards the slot-registration race):
  {"type":"prompt","prompt":"<= 4000 chars","scripted":"steward|opportunist|"}
Any other frame is ignored with a log line.

The doctrine the game asks the model for, per role, with the caps it enforces: grass {seed_threshold 60..200, seed_range 24..240, seed_cost 20..80, crowd_limit 0..6}; grazers {birth_threshold 80..240, bite 2..14, flee_range 0..300, herd 0..100}; predators {birth_threshold 150..400, hunt_range 40..400, rest_energy 0..400, spread 0..100}. `say` is capped at 64 runes, `notes` at 400; both are truncated on rune boundaries. Out-of-range doctrine values are clamped, a missing one is an invalid reply.