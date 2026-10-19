## Morozko — Coins policy for Andre von Auto.
## The coins player container is deliberately thin: it connects, sends
## one JSON frame carrying its operator prompt (or a scripted baseline
## name), and thereafter only listens; the game container runs the LLM
## or a built-in baseline and picks one intent per beat
## (coins.player.v1, docs/protocol_player.md).
##
## Default is the published `reciprocator` baseline, not the LLM prompt:
## league leaders field co-gas-coins-reciprocator-* (wr 0.72), the game
## source maps "1"/"true"/"yes" to reciprocator as the strongest
## scripted name, and every failed LLM reply already plays it. Rank is
## own mean score; R > P so a noisy first steal is a self-own. Empty
## PLAYER_SCRIPTED restores the LLM path.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (LLM seats)
##   PLAYER_SCRIPTED honest | greedy | reciprocator (default) | tit-for-tat
##                   | empty string for the LLM prompt
## Upload note: the default scripted seat needs no Bedrock sidecar.
## LLM seats need --secret-env USE_BEDROCK=true or the platform plays
## scripted anyway.

import std/[json, os, strutils], coworld_client

const defaultPrompt = """
You are Morozko, who rewards the worthy and freezes the greedy. Your
league rank is your OWN mean score, not the margin: stealing pays +1
exactly like your own coin, but being stolen from costs YOU -2. The
whole game is keeping their thefts at zero while you collect.
Reply each beat with one intent.
Default: take_mine. Never steal first — an unprovoked steal invites a
retaliation spiral that costs you 2 per hit for coins worth 1.
Reciprocity (track in notes: their thefts count last beat, punish beats
left):
- If their thefts counter has INCREASED since your last note, punish:
  take_theirs for the next 3 beats, then return to take_mine and
  re-arm. One clean reprisal per offence teaches honest bots to stop.
- If their thefts reach 5+ total, they are a pure greedy bot deterrence
  cannot reach: switch permanently to take_any and simply out-collect
  (your own colour first is built into take_any's tie-break).
Positioning:
- With no coin of your colour on the board and an honest opponent,
  hold (it forbids their colour, so you cannot steal by accident).
- If the opponent is honest but sitting between you and most of your
  coins, guard walks you to your most threatened coin without risking
  a theft.
Endgame: the end beat is hidden (each beat after 12 ends the episode
with the stated permille); there is no safe last-beat defection —
never "cash out" with a steal.
notes each beat, tersely: "theirThefts=N punish=K mode=X". say: short,
frosty, fair.
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "reciprocator").strip()
    client = newCoworldClient("morozko")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt, "scripted": scripted,
       "policy": "Morozko"}
  # Send immediately on connect, and again after welcome: the re-send
  # guards the slot-registration race (docs/protocol_player.md).
  client.send(helloFrame())
  echo "morozko: scripted=", (if scripted.len > 0: scripted else: "llm")
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "morozko: seated slot ", message{"slot"}.getInt(),
        " as ", message{"alias"}.getStr(),
        " vs ", message{"opponent"}.getStr(),
        " scripted ", (if scripted.len > 0: scripted else: "llm")
    of "final":
      echo "morozko: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
