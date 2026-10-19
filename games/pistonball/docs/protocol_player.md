# Pistonball — the player socket

    GET /player?slot=<N>&token=<T>

A bad slot or token is refused with 403 BEFORE the websocket upgrade. Joins are
strictly slot-sequential.

## What a seat sends: one registration, and nothing else

A seat sends exactly ONE kind of message, a Sprite v1 chat frame carrying its
registration:

    {"type":"register",
     "prompt":"<strategy text or empty>",
     "scripted":"wavebot"|"metronome"|null,
     "policy":"<free label>"}

It is re-sent for the first ~10 s of frames, because a seat's first
registration routinely arrives before its player index exists; the server HOLDS
an unappliable registration rather than dropping it. A seat that never
registers, or registers with neither field, plays the scripted "wavebot"
baseline. `prompt` is capped at 4000 runes at the transport — over-long is
truncated, never rejected — and is NEVER written to the replay or the results.

SEATS SEND NO INPUTS. Every command byte is computed server-side by the
deterministic controller from the seat's current script; an input mask arriving
on a player socket is discarded. The seat sends the Sprite v1 Ready packet
(0x85) after each received frame and otherwise only receives.

## What a seat receives: its own metre of the world

One binary Sprite v1 frame per tick, filtered by the SAME window predicate the
LLM view uses: the housing and floor, the five piston heads i-2 .. i+2, this
seat's own head highlighted, and the ball only while its centre is inside the
+/-1.00 m window. Everything else is dark. Board labels carry only the
anonymous alias PST-nn — never an entrant's name.

## The per-seat view and the reply

Every 225 ticks (9.375 s) the server composes this seat's view — the same
function that builds the frame filter — and asks the seat's policy for its
piston's program for the next turn. Numbers are rounded to 2 decimals, in view
coordinates (metres, origin bottom-left, y up) and degrees per second.

    {"turn": 3, "of": 8,
     "clock": {"tick": 675, "of": 1800, "left_s": 46.9},
     "you": {"alias": "PST-08", "piston": 7, "x_m": 3.80,
             "height_m": 0.92, "velocity_m_s": 0.00,
             "stroke_m": 1.60, "max_speed_m_s": 1.92, "width_m": 0.40},
     "window": {"half_width_m": 1.00, "covers_pistons": [5, 6, 7, 8, 9],
                "neighbour_heights_m": {"5": 0.10, "6": 1.44, "7": 0.92,
                                        "8": 0.31, "9": 0.00},
                "ball": {"dx_m": -0.34, "height_m": 1.31, "vx_m_s": -2.14,
                         "vy_m_s": 0.22, "spin_deg_s": -310.0, "on_me": true}},
     "sightings_count": 41,
     "sightings": [{"tick": 611, "dx_m": 0.98, "height_m": 0.55,
                    "vx_m_s": -1.90, "vy_m_s": 0.05}],
     "shared_reward": {"last_turn": 6.42, "note": "..."},
     "goal": {"direction": "left", "your_distance_to_goal_m": 2.60,
              "note": "..."},
     "your_last_script": {...}}

`window.ball` is null whenever the ball is outside the window, and `sightings`
is [] when the seat saw nothing at all last turn — which is the common case.
Hidden with no exception: the ball's absolute position whenever it is outside
the window, the cumulative reward, bestX, the score so far, any piston height
outside i-2 .. i+2, which entrant holds any other piston, any other seat's
script or note or say, perm, the seed, and every real player name.

The reply is one JSON object:

    {"note": "<=160 runes",
     "mode": "wave"|"lift"|"drop"|"hold"|"catch"|"ripple",
     "trigger_m": 0.0..1.0,
     "lead_ticks": 0..24,
     "up_m": 0.0..1.6,
     "down_m": 0.0..1.6,
     "idle_m": 0.0..1.6,
     "speed": 0.0..1.0,
     "blind": "hold"|"idle"|"ripple",
     "say": "<=48 runes"}

Parsing is TOLERANT: markdown fences are stripped, the outermost balanced
{...} is taken if the model prefixed prose, numeric strings are accepted,
integer percentages and centimetres are divided by 100, and mode/blind are
matched case-insensitively. Every bounded field is REPAIRED rather than
rejected. Only when no object with at least one usable field can be recovered
do the single retry and then the scripted fallback fire. Every truncation lands
on a RUNE boundary, never a byte boundary.
