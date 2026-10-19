factory_commons.player.v1 — JSON text frames over WS /player?slot=N&token=T.

game -> player, on connect:
  {"type":"welcome","protocol":"factory_commons.player.v1","slot":N,"name":"Ratchet","shifts":15,"ticksPerShift":60,"variant":"factory-commons","numAgents":3}

game -> player, at every shift boundary and at the end: a `state` frame carrying the seat's whole observation — the floor geometry, the machine (integrity, cap, band, mode, cooldown, both stocks, both current yields, whether each operation is legal right now, and the lifetime press/strip/repair/banana counts), both cubes' loose counts and the nearest unit to the seat, every chute cell's banana count and oldest ttl, all three cogs' cells / carried cube / eaten / banked / score / action counts / last shift's order and last shift's `say`, the full per-shift history, the seat's own private notes, the precomputed legal job list, and every rule constant. NOT in it: the other seats' orders for the shift about to be played (decisions are simultaneous), their notes, any policy or player or model name, and the seed.

game -> player, terminal:
  {"type":"final","done":true,"slot":N,"scores":[...3...],"names":[...aliases...],"shifts":S,"reason":...,"ending":...}
after which the player exits 0.

player -> game, immediately on connect AND again after `welcome` (the re-send guards the slot-registration race):
  {"type":"prompt","prompt":"<= 4000 chars","scripted":"steward|stripper|freerider|"}
Any other frame is ignored with a log line.

REPLY SCHEMA (the game asks Claude, not the player process): one JSON object, {"job", "cube", "say", "notes"}. job in operate | strip | maintain | eat | idle (required); cube in pink | blue | any (optional, default any); say <= 90 characters; notes <= 320 characters. BOTH STRING CAPS ARE RUNE COUNTS AND TRUNCATION IS ON RUNE BOUNDARIES — a byte cut puts invalid UTF-8 into the replay and only a strict parser finds it. FALLBACK CONTRACT: invalid or failed replies are retried once in the same shift's batch with a hint, then fall back to the scripted `steward` order, recorded as source: "fallback" and counted in results.fallbacks[i]. decideAll never raises; the episode always advances.