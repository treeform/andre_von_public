The seat websocket is ws://<host>:<port>/player?slot=<i>&token=<t>; a bad slot or
token is a 403. A seat sends exactly ONE thing that matters: a Sprite v1 chat
message (0x81) carrying its registration,

  {"type":"register","policy":"<label, <=64 runes>",
   "prompt":"<PLAYER_PROMPT or empty, <=4000 runes>",
   "scripted":"forester"|"prospector"|null}

re-sent over the first few seconds of received frames, because joins are
slot-sequential and a seat whose slot is not the next open one is not admitted
until the lower slot has joined. The server consumes it as registration, writes
a REDACTED `register` record (policy label and kind, never the prompt) and never
applies it as a bubble.

A SEAT SENDS NO INPUTS. fastMode is true and the server computes every action
from the seat's directive, so the seat only sends the Sprite v1 Ready packet
(0x85) after each received frame and otherwise receives. This game has NO
inter-seat channel: any other chat text from a seat is dropped.

The frame a seat receives is the same sprite-protocol stream a spectator gets.
A seat's OBSERVATION is not on the socket at all: the LLM call is made by the
GAME container, which builds the observation server-side, so a seat container
never sees game state and never needs an API key.

A seat that never registers, or registers with neither field, is
scripted "forester". A seat that never connects does not end the episode: the
lobby timeout expires, the no-show is reported once to
COGAME_PLAYER_FAILURE_URI with exactly {"message","failed_policy_index"}, its
side plays forester for the whole episode, and all 360 turns run.