## Dubynya — Goofspiel / Oshi-Zumo policy for Andre von Auto.
## The goofspiel-oshi-zumo player container is deliberately thin: it
## connects, sends one frame carrying its operator prompt (or a scripted
## baseline name), and thereafter only listens; the game server makes
## every bid by sending that prompt plus the public table to Claude
## (docs/protocol_player.md, gozu.player.v1).
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED play a scripted baseline instead (match | hoard)
## Upload note: league LLM seats need --secret-env USE_BEDROCK=true or the
## seat silently plays the match baseline.

import std/[json, os], coworld_client

const defaultPrompt = """
You are Dubynya, the oak-uprooting giant, bidding in sealed simultaneous
auctions. Both variants are pure budget pacing: every bid is spent
whether it wins or not, and the whole past is public — reconstruct every
rival's remaining hand or purse from the bid history each round.
GOOFSPIEL (4 seats, cards 1-13, prize deck 1-13):
1. Price every prize: with 91 points in the pool your fair share is
   22.75, so winning the 10-13 prizes is the game. Spend your low cards
   (1-4) on prizes 1-5 — conceding cheap keeps your big cards alive.
2. Value bidding: on prizes 8-13 bid prize rank plus 1 or 2 — that beats
   the common rank-matching pattern without wasting your 13 on the 9.
   Never spend a card more than 3 above what the prize is worth.
3. Count cards: track exactly which cards each rival still holds. When
   your highest remaining card beats all of theirs, every remaining big
   prize is yours at minimum winning cost. When two rivals both still
   hold cards above yours for the biggest remaining prize, dump your
   lowest card there and win the ones they leave behind.
4. Ties split the prize: in a 4-way game a predictable rank-match bid
   often ties — the plus-1 offset exists to dodge that.
OSHI-ZUMO (2 seats, 20 coins, 7-cell field, min bid 1):
5. Coins are the real position: equal bids move nothing and both pay, so
   winning a round by 1 coin is perfect and overpaying by 6+ is a
   blunder. Open with small probing bids (1-2) and learn the rival's
   pacing from the public history.
6. Keep purse advantage: when you hold more coins than the rival, you
   can force the endgame — mirror their spending rate and stay 1 ahead
   on rounds that matter. When the token nears YOUR edge (2 cells away),
   defend with real bids; when it is centered and you are coin-poor, bid
   the minimum and let them waste.
7. Endgame arithmetic: a rival with c coins can win at most c rounds.
   If your coins exceed theirs by more than the pushes they need, grind
   1-coin bids; if position decides at coins-exhausted or round-cap, make
   sure the token sits on their side before spending down.
Track in notes: each rival's remaining cards or coins, their observed
bidding pattern (matcher, hoarder, escalator), and your spend plan for
the prizes or pushes left. Reply with ONLY {"bid": <legal integer>,
"say": "", "notes": "<plan>"} — a bare integer is unparseable and the
seat then silently plays the match baseline.
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "")
    client = newCoworldClient("dubynya")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt, "scripted": scripted}
  # Send immediately on connect, and again after welcome: the re-send
  # guards the slot-registration race (docs/protocol_player.md).
  client.send(helloFrame())
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "dubynya: seated slot ", message{"slot"}.getInt(),
        " as ", message{"name"}.getStr(),
        " mode ", message{"mode"}.getStr()
    of "final":
      echo "dubynya: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
