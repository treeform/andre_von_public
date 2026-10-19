THE PLAYER SOCKET (ws://<game>/player?slot=N&token=T)

A seat sends exactly ONE message that matters and then only receives.

1. REGISTRATION. One Sprite v1 chat frame (0x81), a JSON object:
     {"type":"register","prompt":"<strategy text or empty>",
      "scripted":"arcader"|"hoover"|null,"policy":"<free label>"}
   `prompt` non-empty makes the seat an LLM seat; `scripted` names a published
   baseline; a seat that sets neither is `arcader`, and the server LOGS THAT
   LOUDLY. The registration is re-sent for the first ~10 s of frames because a
   seat's slot may not be admissible yet; the server holds an unappliable
   registration rather than dropping it. `prompt` is capped at 4000 runes at
   the transport (truncated, never rejected) and is NEVER written to the
   replay or the results.

2. FRAMES. One binary Sprite v1 message per tick carrying THIS SEAT'S LANE
   ONLY: its whole 17x17 screen, every tile, every sprite, its avatar, its
   lives and its points. The other three quadrants are not in a player frame
   at all. Board labels carry only the colour aliases RED / BLUE / GREEN /
   YELLOW; `showPlayerLabels` is forced false on this stream.

3. READY. The seat replies with the Sprite v1 ready packet (0x85) after each
   received frame. SEATS SEND NO INPUTS: every action byte is computed
   server-side by the autopilot, so an input mask arriving on a player socket
   is discarded.

THE DECISION. Every 120 ticks (5.0 s) the GAME server composes this seat's
board view and asks the seat's policy for one STANCE. The view is the seat's
own screen as a 17-line ASCII map plus structured `threats`, `targets`,
`zones`, its own counters, and a four-row SCOREBOARD strip carrying every
rival's {alias, score, lives, screen} and nothing else. The reply is:

  {"note":"<=160 runes","mode":"clear|hunt|strike|safe|bank",
   "zone":"nw|ne|sw|se|centre|left|right|top|bottom|none",
   "risk":0.0..1.0,"lead_ticks":0..48,
   "fire":"auto|hold|never","say":"<=48 runes"}

Parsing is tolerant (markdown fences, prose prefixes, percentages, synonyms);
every field is repaired rather than rejected; two consecutive failures fall
back to the published `arcader` stance and write a `fallback` record.