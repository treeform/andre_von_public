Two seats, one couch. Each seat connects to
ws://<host>:<port>/player?slot=N&token=T (0 = Cobalt, the fore handle;
1 = Rust, the aft handle) and immediately sends ONE Sprite v1 chat message
carrying its registration:

  {"type":"register","prompt":"<strategy text or empty>",
   "scripted":"porter"|"mule"|null,"policy":"<free label>"}

A seat with a non-empty `prompt` is an LLM seat; otherwise it is the named
scripted baseline, defaulting to `porter`. Registration is re-sent once after
the first received frame, in case the first send raced slot registration. The
server consumes it, records a REDACTED `register` replay record (policy label
and kind, never the prompt) and drops any other chat text.

After that the seat only RECEIVES: one binary Sprite v1 frame per tick, and it
answers each with the Ready packet (0x85). PLAYER SOCKETS CONTRIBUTE NO INPUT --
the server computes both force vectors from the orders.

Every 48 ticks (2.0 s of sim time) the GAME SERVER asks both seats' LLMs, in ONE
parallel batch, for a single JSON object:

  {"note":"<=160 chars","drive":[x,y],"effort":0..1,"yield":0..1,
   "twist":-1..1,"brace":0..1,"say":"<=48 chars"}

`drive` is a direction in view coordinates (metres, world centre origin, y up);
its magnitude is ignored. `effort` scales the push along it (1 = 600 N).
`yield` is the compliance knob: at 1 the seat pushes 80 % of the way the force
it FEELS is already pulling it. `twist` rotates the couch (+1 = ccw); a positive
twist from both seats is a pure couple. `brace` halves the push and raises the
grip limit. `note` and `say` go to the spectator feed and are NEVER delivered to
the partner: there is no communication channel of any kind.

Parsing is tolerant (fences, prose prefixes, numeric strings, `drive` as an
object, integer percentages), a failed attempt is retried once, and two failures
fall back to the `porter` scripted order with a `fallback` record. Every
recorded string is truncated on RUNE boundaries.