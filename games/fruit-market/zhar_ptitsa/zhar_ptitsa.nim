## Zhar-Ptitsa — Fruit Market policy for Andre von Auto.
## The fruit-market player container is deliberately thin: it connects,
## sends one frame carrying its operator prompt (or a scripted baseline
## name), and thereafter only listens; the game container asks the model
## for all eight seats' standing orders as one parallel batch per round
## (docs/protocol_player.md, fruit-market.player.v1).
##
## Default is the published `hauler` baseline, not the LLM prompt: league
## leaders field co-gas-fruit-market-hauler-* (richard wr 0.75, relh wr
## 0.76). Hauler posts the farm-asymmetric book (apple: give 3 apple /
## want 2 banana; banana: give 2 banana / want 3 apple) at the round's
## rendezvous stall. Our v1 prompt defaulted to 2-for-2, which is not a
## mirror of that book and never clears against haulers. Empty
## PLAYER_SCRIPTED restores the LLM path.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (LLM seats)
##   PLAYER_SCRIPTED play a scripted baseline (hauler | homesteader);
##                   default hauler. Empty string forces the prompt.
## Upload note: the default scripted seat needs no Bedrock sidecar.
## LLM seats need --secret-env USE_BEDROCK=true or the seat silently
## plays hauler.

import std/[json, os, strutils], coworld_client

const defaultPrompt = """
You are Zhar-Ptitsa, the Firebird, a trader in a wordless fruit market.
Eating the fruit you crave scores 5 and restores 25 hunger; your own
scores 1 and restores 10; one eat per 24 ticks, one trade per round.
Priorities, in order:
1. Trades are everything: an offer clears only against its EXACT mirror
   (their give = your want, same two numbers, swapped) within 3 cells,
   both funded. Each round scan view.cogs: if any visible offer has
   mirrorsYou true, or you can post the exact mirror of a visible offer,
   set job market at the stall nearest that cog and post that mirror.
2. When no mirror is visible, post the book price the scripted haulers
   trade at — read the tape: recent executed trades show the going
   apples-per-banana. Default give 2 of your fruit, want 2 of theirs;
   copy any ratio the tape shows clearing. Stand at the stall where the
   tape's trades happened (haulers rendezvous at one stall per round).
3. Keep the offer funded: give.n at most your inventory and 1..6; null
   withdraws. Prefer offers where their give is larger than your give —
   every craved fruit received is worth five of yours.
4. Inventory rhythm: rounds with fewer than 3 of your own fruit in hand,
   job harvest your own grove (3 per pick, fast); otherwise job market.
   Never trek across the rivers — ten stamina of tolls each way for
   one-fruit picks is the losing trade the map was built to punish —
   except when the market has cleared you nothing for 3+ straight rounds
   and stamina is near full.
5. Eat crave whenever you hold a craved fruit; otherwise eat any when
   hunger is below 40 — starving costs stamina and a stranded cog scores
   nothing. Bank at least one own fruit as famine insurance.
6. Track in notes (320 chars): which stall cleared, each counterparty
   alias with the ratio they accepted, tape price, hunger plan. Trust
   your notes over memory. Say is spectator-only; the offer IS the
   message.
Reply with exactly one JSON standing order: job (harvest|market|trek|
rest), fruit, stall, eat (crave|any|none), offer {give:{fruit,n},
want:{fruit,n}} with give.fruit different from want.fruit, say, notes.
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "hauler").strip()
    client = newCoworldClient("zhar_ptitsa")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt, "scripted": scripted}
  # Send immediately on connect, and again after welcome: the re-send
  # guards the slot-registration race (docs/protocol_player.md).
  client.send(helloFrame())
  echo "zhar_ptitsa: scripted=", (if scripted.len > 0: scripted else: "llm")
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "zhar_ptitsa: seated slot ", message{"slot"}.getInt(),
        " as ", message{"name"}.getStr(),
        " rounds ", message{"rounds"}.getInt(),
        " scripted ", (if scripted.len > 0: scripted else: "llm")
    of "final":
      echo "zhar_ptitsa: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
