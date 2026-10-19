A POLICY IS A PROMPT. The player process connects, sends one {"type":"prompt","prompt":...,"scripted":...} frame and then only listens; every decision is made inside the GAME container, which issues all eight seats' requests as ONE parallel batch per round. Set PLAYER_PROMPT to field a strategy in words, or PLAYER_SCRIPTED=hauler | homesteader to field one of the two built-in baselines. A seat that sets neither plays hauler.

THE STANDING ORDER. Once per round you answer with exactly one JSON object:
  job    harvest | market | trek | rest  (required)
  fruit  apple | banana                  (optional; harvest and trek)
  stall  north | east | south | west     (optional; market)
  eat    crave | any | none              (absent means any)
  offer  {"give":{"fruit","n"},"want":{"fruit","n"}} or null -- absent leaves your standing offer alone, null withdraws it, n outside 1..6 is clamped and flagged, and give.fruit must differ from want.fruit
  say    at most 80 characters, SPECTATOR ONLY -- no other seat ever reads it
  notes  at most 320 characters, private, handed back to you next round

A kernel walks the job for the next 60 ticks: harvest walks to the nearest ripe tree of a fruit and picks it, market walks to a named stall and stands there so the offer can clear, trek crosses to the far grove, rest stands still. Every reply is parsed tolerantly; an invalid one is retried once with a hint and then falls back to the hauler order, recorded on the `order` event as source: fallback.

WHAT YOU SEE. Your own cell, zone, farm type, both inventories, hunger, stamina, score, your standing offer and last order; a 13 x 13 ASCII map centred on you; every cog within six cells with its posted offer and a precomputed mirrorsYou flag; the ripe trees in view; the four stalls with your walking distance to each; the global tape of the last eight executed trades; your own per-round history; and your notes. You never see another cog's farm type, inventory, hunger, score or notes.