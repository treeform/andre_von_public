THE RING — the player wire contract.

GET /player?slot=<N>&token=<T> upgrades to a websocket. A slot with a
configured token demands exactly that token; a mismatch is refused 403 and the
socket is closed.

A seat sends ONE Sprite v1 chat message carrying its registration and then only
receives:

  {"type":"register","prompt":"<strategy text or empty>",
   "scripted":"pusher"|"anchor"|null,"policy":"<free label>"}

A non-empty `prompt` makes the seat an LLM seat (capped at 4000 runes at the
transport, truncated never rejected, and NEVER written to the replay or the
results). `scripted` names a published baseline. A seat that sets neither field,
or never registers at all, is `pusher`, and the server logs that out loud. The
registration is re-sent on a bounded schedule because joins are slot-sequential
and the lobby sends frames to a socket before it is admitted; the server HOLDS
an unappliable registration rather than dropping it.

SEATS SEND NO INPUTS. Every command byte is computed server-side by the
deterministic controller, so any input mask arriving on a player socket is
discarded. After each received frame the seat sends the Sprite v1 Ready packet
(0x85), which lets a fastMode server advance the tick as soon as both seats have
acknowledged the frame.

Each seat receives one binary Sprite v1 frame per tick. The game is
perfect-information on the physics: the frame carries the ring, the current rim
radius, both bugs with all eight feet, both tilt gauges and both round tallies.
Board labels carry ONLY the anonymous aliases BUG-1 and BUG-2.

Every 36 ticks (1.5 s) the seat is asked for ONE tactical order. The observation
it is given is in view coordinates (metres, origin bottom-left, y up, bearings
in degrees counter-clockwise from east, every number rounded to 2 decimals) and
carries: the turn index, the clock, the ring (centre, live radius, minimum
radius, when the shrink starts, the radius at the round clock), your bug and the
other bug in full physical detail (position, velocity, speed, heading, spin,
posture, effort, reach, tilt percent, grounded legs, down ticks, distance from
the centre, distance to the rim, all four foot positions), the contact state,
the match tallies and round log, the scoring rules, and your own last order.

HIDDEN from every seat with no exception: the other seat's order object, note,
say, prompt text, latency, policy kind, policy label and fallback state; which
entrant holds the other seat; any real player name; `perm`; `config.seed`; the
RNG state; the future start axes; and the variant name.

THE REPLY is a single JSON object beginning with '{':

  {"note":"<=160 runes","stance":"charge"|"brace"|"circle"|"lift"|"retreat"|"centre",
   "aim":"foe"|"centre"|"bearing","bearing_deg":0..359,"aggression":0..10,
   "posture_bias":"low"|"even"|"high"|"auto","lead_ticks":0..24,
   "circle_dir":-1|1,"say":"<=48 runes"}

Every field is REPAIRED rather than rejected: an unrecognised stance keeps last
turn's, else `charge`; a missing aim is `foe`; numbers are clamped; `note` and
`say` are truncated on RUNE boundaries. Parsing is tolerant of markdown fences,
prose prefixes, numeric strings, percentages for `aggression`, radians for
`bearing_deg`, "cw"/"ccw" for `circle_dir`, seconds for `lead_ticks`, and the
synonyms "push" (charge) and "hold" (brace). Only when no object with at least
one usable field can be recovered do a single retry and then the scripted
fallback fire — no failure mode leaves a bug uncommanded.

At aggression 10 the autopilot's rim guard is HALVED: an all-in push may put you
out. That is the documented trade, not a trap.
