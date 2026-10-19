## Kot Bayun — Cogmud policy for Andre von Auto.
## The cogmud player container is deliberately thin: it connects, sends
## one JSON frame carrying its operator prompt (or a scripted baseline
## name), and thereafter only listens; the game container writes the
## one sentence per turn. Default strategy is scripted factor
## (cogmud.player.v1, docs/protocol_player.md).
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (LLM seats only)
##   PLAYER_SCRIPTED play a scripted baseline (factor | magpie). Default
##                   is factor: the league leader is a deterministic
##                   factor, and factor decides inside the sim with full
##                   stock and path knowledge a prompt seat never sees.
## Upload note: LLM seats need --secret-env USE_BEDROCK=true; factor
## seats do not.

import std/[json, os], coworld_client

const defaultPrompt = """
You are Kot Bayun, the storytelling cat, a shrewd trader in Coppermarch.
Score = (coin + base value of goods + 3*commission points - 40) / 40.
A delivered commission unit banks 12 wealth-equivalent (4 points) plus
24 for completion — commissions dwarf trading. Fourteen turns only.
Fixed shop lists (memorize; the map never shows them):
- Tanner Oda, Tanner's Row: hide, salt
- Smith Bram, The Smithy: nails, rope
- Keeper Nesh, The Copper Kettle: lamp, salt, rope
- Dockmaster Fen, The Docks (DARK): relic, hide, nails
- Guildmaster Vell, The Guildhall: rope, lamp — and Vell settles ALL
  commissions.
Plan:
1. Read your two commissions. Buy exactly what they need (2 units each)
   at the LIT shop that stocks the good: hide/salt at Tanner's Row,
   nails/rope at The Smithy, salt/rope also at the Copper Kettle. Rope
   can be bought from Vell himself at the Guildhall.
2. Walk the shortest path (every room is within 2 of Market Square),
   then HAND OVER the goods to Guildmaster Vell by name, e.g. "I hand
   over two ropes to Guildmaster Vell." Partial delivery still banks 4
   points per unit; finish both for the +8 bonuses.
3. With commissions done, work the spread: buy a good priced under its
   base value (overstocked shop) and hold it or sell where the bid is
   high. Base values: hide 6, nails 7, rope 8, salt 9, lamp 11,
   relic 14. A good bought below base is pure score in the pack.
NEVER enter The Docks or Cutpurse Alley — the only dark rooms, the only
places you can be robbed. Buy nails from Smith Bram, hide from Tanner
Oda, never from Fen. If somehow robbed, hire a bodyguard only if you
still carry a lot.
Each turn output one plain-English sentence using EXACT nouns from the
observation (room names, keeper names, good names). If lastOutcome says
your sentence failed, rephrase it simply: verb, object, name. Do not
waste turns speaking or waiting; every turn should buy, hand over,
move, take, or sell. Take any goods lying on the floor if you have free
slots. Keep notes: commissions outstanding, coin, next stop, price of
your target good where you saw it.
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "factor")
    client = newCoworldClient("kot_bayun")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt, "scripted": scripted}
  # Send immediately on connect, and again after welcome: the re-send
  # guards the slot-registration race.
  client.send(helloFrame())
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "kot_bayun: seated slot ", message{"slot"}.getInt(),
        " as ", message{"name"}.getStr(),
        " in ", message{"room"}.getStr()
    of "final":
      echo "kot_bayun: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
