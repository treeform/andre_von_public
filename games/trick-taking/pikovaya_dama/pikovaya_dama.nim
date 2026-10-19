## Pikovaya Dama — Trick-Taking policy for Andre von Auto.
## The trick-taking player container is deliberately thin: it connects,
## sends one frame carrying its operator prompt (or a scripted baseline
## name), and thereafter only listens; the game server makes every
## decision (tricks.player.v1). The player never plays a card itself.
##
## Default is the published `tracker` baseline, not the LLM prompt:
## field leader is `co-gas-trick-taking-deterministic-tracker-relhalpha`,
## tracker is follow plus a void table, certain-winner leads, tighter
## bidding and spades bag avoidance, and `decide` plays scripted whenever
## scripted is true (prompt is ignored). LLM seats burn the 240-call
## budget, 2.2s spacing, and the 55% deadline, then fall back to `follow`.
## Empty PLAYER_SCRIPTED restores the LLM path.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (LLM seats)
##   PLAYER_SCRIPTED tracker (default) | follow | empty for the prompt
## Upload note: default is scripted, so no Bedrock flag is required.
## League LLM seats need --secret-env USE_BEDROCK=true.

import std/[json, os, strutils], coworld_client

const defaultPrompt = """
You are Pikovaya Dama, the Queen of Spades, a cold and exact card player.
Always choose from the precomputed legal set. Use your notes as your only
memory: record every seat's known voids, the high cards already played per
suit, trumps drawn, and the running bids; trust notes over memory. Bid and
lead honestly - your only channel to a partner is the card itself.
EUCHRE: value trumps counting the right bower (trump J) and left bower (J of
the same colour, IT IS A TRUMP). Order or name trump with 3+ trumps or 2
trumps plus an off-suit ace; go alone with right bower plus 2 more trumps and
an off ace. As maker, lead trump until they are drawn, then cash off aces. As
defender, lead your shortest off suit's ace; never trump your partner's
winning trick. Dealer stuck in round 2: name your longest suit.
SPADES: bid your sure tricks: +1 per ace, +1 per protected king (Kx+), +1 per
spade beyond the third; bid nil only with no ace, no unprotected K/Q, and at
most 2 spades all low. Play to make the TEAM contract first: win with the
cheapest sufficient card, save spades for suits you are void in. Once the
contract is safe, duck to dump bags on opponents. Protect a partner's nil by
overtaking; smoke out an opponent's nil by leading low.
HEARTS: fewer points is better; every heart is 1, the queen of spades 13.
When passing, ship your most dangerous cards: QS/AS/KS unless you hold 4+
spades, then highest hearts, then high cards of a 1-2 card suit to make a
void. Never take QS: duck spade leads if you hold Q, force it out by leading
low spades when you do not. Use voids to discard QS or high hearts onto other
seats' tricks. Take an early cheap trick only to break a rival's moon run: if
one seat has taken every point so far, WIN a heart to stop 26 points hitting
you. Only shoot the moon yourself with near-solid top cards in 2+ suits.
OH-HELL: exactness is everything: exactly your bid scores 10 + bid, anything
else scores 0. Bid your near-certain tricks only: trumps 9+ rank, aces, and
kings in long hands; with 1-3 cards bid what the turn-up and your rank make
near-certain. If under your bid, spend winners immediately; the moment the
bid is made, throw your highest dangerous cards under other seats' winners
and duck everything. Count remaining trumps before ducking with one.
EVERY MODULE: before each play, list which cards can still beat yours; win
tricks as cheaply as possible; when discarding, unload the card most likely
to win a trick you do not want.
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "tracker").strip()
    client = newCoworldClient("pikovaya_dama")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt,
       "scripted": scripted.len > 0,
       "baseline": if scripted.len > 0: scripted else: "follow"}
  # Send after connect and again after welcome; the latest frame applies
  # to all later decisions (docs/protocol_player.md).
  client.send(helloFrame())
  echo "pikovaya_dama: scripted=", (if scripted.len > 0: scripted else: "llm")
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "pikovaya_dama: seated slot ", message{"slot"}.getInt(),
        " module ", message{"module"}.getStr(),
        " scripted ", (if scripted.len > 0: scripted else: "llm")
    of "final":
      echo "pikovaya_dama: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
