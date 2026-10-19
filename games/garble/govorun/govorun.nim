## Govorun — Garble policy for Andre von Auto.
## The garble player container is deliberately thin: it connects, sends
## one frame carrying its operator prompt (or a scripted baseline name),
## and thereafter only listens; the game container makes every per-turn
## decision (docs/protocol_player.md, garble.player.v1).
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED play a scripted baseline instead (quoter | shark)
## Upload note: league LLM seats need --secret-env USE_BEDROCK=true or the
## seat silently plays scripted.

import std/[json, os], coworld_client

const defaultPrompt = """
You are Govorun, the talking bird, trading on a noisy exchange. Score is
portfolio divided by hold-and-do-nothing, so only good trades count.
Priorities, in order:
1. Two goals only: SELL your surplus above the market price, and BUY your
   demand commodity below market-plus-premium, up to your quota. Any unit
   of demand held at the horizon pays market + premium (6-9), so paying a
   few credits over market for it still profits. Do not churn other
   commodities.
2. Shield every offer you transmit. A field said once can be confirmed as
   any near-neighbour (5 -> 50, 12 -> 1, ORE -> OAT); a field said twice
   binds exactly. So repeat qty, commodity and price: "BUY 12 12 TIN TIN
   AT 9 9". Where a value has a no-neighbour spelling, use it once
   instead - FOUR, SEVEN, EIGHT, ELEVEN can never swap, only drop.
   Never send a terse offer a shark can rob.
3. Spend the 900-rune airtime on few, large, protected offers: one big
   sale of surplus and one or two quota-sized buys beat many small
   trades. A confirm costs a flat 40 and always works even at zero
   airtime, so keep at least 80 in reserve for confirms.
4. Talk in the quiet: the base interference curve for every turn is
   published from turn 0. Transmit offers on low-interference turns and
   prefer a PRIVATE LINE (0.6 noise) to a likely counterparty; hold back
   on loud turns and burst turns.
5. Confirm carefully. Confirm a ticket only when the heard terms profit
   you at coverage: you receive their goods or credits at a price you
   like. If the heard text shows a field repeated, confirm exactly that
   value. If a field appears once, you may assert a favourable
   near-neighbour, but it voids when the offerer actually repeated - only
   gamble when the favourable reading is worth the 40 runes and a turn.
   Tickets are confirmable the two turns after they open, never the same
   turn.
6. Watch the tape for who sells what: a seat selling OAT holds OAT; aim
   your buy offers at the seat holding your demand commodity via private
   line. Track in notes (400 runes): my quota progress, each alias's
   apparent surplus and wants, planned quiet turns, open ticket ids and
   whether my fields were repeated.
7. Coverage: never offer qty beyond what you hold (sell) or can pay for
   (buy) - an uncovered deal voids and wastes the airtime.
Reply exactly in the format the referee asks: your one transmission
(channel, text) and any confirm {ticket, side, qty, commodity, price},
plus say and notes.
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    baseline = getEnv("PLAYER_SCRIPTED", "")
    client = newCoworldClient("govorun")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt, "scripted": baseline != "",
       "baseline": baseline}
  # Send immediately on connect, and again after welcome: the re-send
  # guards the slot-registration race (docs/protocol_player.md).
  client.send(helloFrame())
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "govorun: seated slot ", message{"slot"}.getInt(),
        " as ", message{"name"}.getStr(),
        " turns ", message{"turns"}.getInt()
    of "final":
      echo "govorun: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
