WALKER-WATERWORLD PLAYER PROTOCOL

One seat drives one skimmer. The seat's websocket is ws://<game>/player?slot=<N>&token=<T>; a bad slot or token is refused with HTTP 403 before the upgrade.

REGISTRATION. A seat sends exactly ONE Sprite v1 chat message (0x81), its registration:
  {"type":"register","prompt":"<strategy text or empty>","scripted":"shoal"|"drifter"|null,"policy":"<free label>"}
A non-empty `prompt` makes the seat an LLM seat; `scripted` names a baseline; a seat that sends neither is `shoal`. `prompt` is capped at 4000 runes at the transport (over-long is truncated, never rejected) and is NEVER written to the replay or the results. The registration is re-sent on the first ~10 s of frames because joins are slot-sequential and a seat's index may not exist yet; the server holds an unappliable registration rather than dropping it.

FRAMES. Each seat receives one binary Sprite v1 frame per tick at 24 Hz, sensor-filtered by the same predicate the sensor frame uses: the tank, the rock, its own skimmer with its sixteen rays, the other three skimmers (the pod shares a transponder, so partners are visible at any range), and plankton/poison ONLY while their centres are within 2.40 m of this skimmer's centre. Everything else is dark. Board labels carry only SKIM-1..SKIM-4; a seat never receives a real policy name on any channel.

SEATS SEND NO INPUTS. Every per-tick thrust byte is computed server-side by the deterministic controller from the seat's standing intent, and that byte is what the replay records. An input mask arriving on a player socket is discarded. A seat sends the Sprite v1 Ready packet (0x85) after each received frame so a fastMode server can advance the tick.

THE DECISION. Every 72 ticks (3.0 s) the GAME server composes this seat's sensor frame as JSON and asks the seat's LLM policy for ONE intent. All four seats' calls go out as one parallel batch per turn. Coordinates in that JSON are metres from the tank's bottom-left corner, x right, y up; bearings are degrees counter-clockwise from east; everything is rounded to 2 decimals. The reply must be a single JSON object beginning with '{':
  {"note":"<=160 runes","mode":"hunt"|"escort"|"sweep"|"hold"|"avoid","target":"F1".."F5"|"none","partner":"SKIM-1".."SKIM-4"|"none","waypoint":[x,y],"lead_ticks":0..24,"standoff_m":0.0..2.5,"throttle":0.0..1.0,"say":"<=48 runes"}
Parsing is tolerant (markdown fences, prose prefixes, numeric strings, percentages for throttle, centimetres for standoff_m and the waypoint, {"x":..,"y":..} waypoints, case-insensitive enums) and every out-of-range field is REPAIRED, not rejected: an unknown mode keeps last turn's, an undetected target becomes `none`, a self partner becomes `none`, a bad waypoint keeps last turn's. Two consecutive failures for a seat mean the `shoal` intent for that turn plus a `fallback` record. Every recorded string is truncated on RUNE boundaries, never bytes.

NOBODY CAN TALK. `say` and `note` are one-way to the spectator feed; no skimmer ever sees either, and there is no inter-seat channel of any kind.