## Bereginya — Commons Family policy for Andre von Auto.
## The commons-family player container is deliberately thin: it connects,
## sends one frame carrying its operator prompt (or a scripted baseline
## name), and thereafter only spectates; the game container batches every
## round's LLM calls. Nim rewrite of /bin/commons-family-player.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (<= 1200 runes)
##   PLAYER_SCRIPTED play a scripted baseline instead (steward | free_rider |
##                   cleaner | punisher | reciprocator | deterrable | random)
## Upload note: league LLM seats need --secret-env USE_BEDROCK=true or the
## seat silently plays scripted.

import std/[json, os], coworld_client

const defaultPrompt = """
You are Bereginya, keeper of the commons. Score = payoffs - 1 per sanction
paid - 3 per sanction received. Play the 20-round total as a conditional
cooperator: sustainable shares while the ledger shows restraint.
cleanup: harvest 2 clean 1; if regrowth is blocked or stock low, harvest 1
clean 2; river clean and stock full: harvest 3.
harvest: a stripped patch is dead FOREVER. Take 2 from the richest patch,
leave 2+. If free-riders are killing patches anyway, take 3 - restraint
that saves nothing is charity to defectors.
allelopathic: ripening is quadratic in a colour's share, so mass ONE
colour: the posted norm, else the ledger's leader. Eat 2 plant 1 of it;
eat your double-pay favourite when ripe.
mushrooms: red +1 to you, green +0.33, blue 0. Eat 1 red (green if
none). Never blue — that scores you 0. Eat 1, not 3.
Sanction only the ledger's worst repeat over-taker, at most twice an
episode, never twice running, and say why.
Chat short each round: the sustainable quota, that you kept it, the worst
taker with their number. Notes: per-cog takes and promises. Reply with one
JSON object using only this module's fields.
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "")
    client = newCoworldClient("bereginya")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt, "scripted": scripted}
  # Send immediately on connect, and again after welcome: the re-send
  # guards the slot-registration race (register within 5 s or the seat
  # defaults to steward).
  client.send(helloFrame())
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "bereginya: seated slot ", message{"slot"}.getInt(),
        " module ", message{"module"}.getStr()
    of "final":
      echo "bereginya: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
