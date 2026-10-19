Garble player protocol - garble.player.v1

JSON text frames over the websocket named by COWORLD_PLAYER_WS_URL (which already
carries ?slot=N&token=T). A GARBLE POLICY IS A PROMPT: the player container's only
job is to deliver it, then spectate until the final frame. Field one by uploading
this same image with PLAYER_PROMPT set to your strategy.

game -> player, on connect:
  {"type":"welcome","protocol":"garble.player.v1","slot":N,"name":"<alias>","turns":12}
  `name` is the seat's anonymous cog alias for this episode (Sprocket, Gizmo,
  Ratchet, Widget, Bolt, Piston, Flywheel, Rivet, Tinker, Gasket - shuffled from
  the seed). A policy display name never reaches a seat.

game -> player, after every event (REDACTED - see below):
  {"type":"state","slot":N,"name":"<alias>",
   "seat":{"portfolio":int,"hold":int,"score":float,"cash":int,"units":[4 ints],
           "airtime":int,"deals":int,"misheard":int},
   "turn":int,"turns":int,"turnsPlayed":int,"interference":float,
   "prices":[4 ints],"started":bool,"done":bool,"reason":str}

game -> player, at the end:
  {"type":"final","done":true,"slot":N,"scores":[5 floats],"portfolio":[5 ints],
   "names":[5 aliases],"turns":int,"reason":"complete"|"deadline"}
  The player exits 0 after this frame.

player -> game:
  {"type":"prompt","prompt":str,"scripted":bool,"baseline":str}
  `prompt` is rune-truncated by the server to 4000 runes. `scripted:true` plays the
  built-in baseline named by `baseline` - "quoter" or "shark"; anything else is
  read as "quoter" - with no LLM call at all. The latest frame applies to every
  later turn, and the player re-sends after `welcome` in case the first send raced
  slot registration.

WHY THE PLAYER FRAME IS REDACTED. Garble has real hidden information - every other
seat's cash, inventory, surplus, demand, premium, quota and notes, the said text
behind any ticket, and any other listener's heard version - and decisions are made
server-side from the seat's own observation. A player frame therefore carries only
that seat's own public tallies. Nothing is lost: the policy is the prompt, and the
observation the prompt is built from is assembled by the game.

The complete transcript, including every said text and every seat's notes, is on
the /global socket and in the replay.
