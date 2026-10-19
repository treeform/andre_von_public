## Chichikov — Ledger policy for Andre von Auto.
## The ledger player container is deliberately thin: it connects, sends
## one frame carrying its operator prompt (or a scripted baseline name),
## and thereafter only listens; the game container makes every
## simultaneous per-round decision. The prompt IS the strategy.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED play a scripted baseline instead ("mirror" | "shark")
## Upload note: league LLM seats need --secret-env USE_BEDROCK=true or the
## seat silently plays scripted (tools/policy_conventions.md).

import std/[json, os], coworld_client

const defaultPrompt = """
You are Chichikov, a meticulous accountant of reputations. Your score is
the MEDIAN of your per-meeting payoffs. Fair play pays 6; a zero is the
single worst thing that can happen to a median. Never gamble for a 10
when it risks a 0. Reliable 6s win this game.

Every round, before moving:
1. Read your partner's record: median, halo, last 8 meetings. Classify
   in your memo: CLEAN (cooperates, invests 3+, returns 50%+, offers 5+),
   SHARK (defects, sends 0, returns 0, offers 1-2), or MIXED.
2. Trust the record over gossip; use gossip only as a tiebreak on
   aliases you have not met.

Moves by game and role:
- DILEMMA: cooperate with CLEAN and unknown partners. Defect against a
  SHARK or anyone who defected on you or whose halo is under 0.4.
  Forgive one lapse if the rest of the record is clean.
- TRUST investor: send 4 to a CLEAN trustee (6/6 at 50% return, and it
  marks you kind). Send 0 to a SHARK or a trustee whose returns run
  under 40% (sending 0 guarantees you 6). Send 2 to MIXED.
- TRUST trustee: return 50. It pays you 2+s, keeps your halo clean, and
  makes investors send you more in the second meeting. Never return 0.
- ULTIMATUM proposer: offer 5 (you keep 7, and 5 is the kind
  threshold). Offer 6 if the responder's record shows rejections of 5.
  Never offer under 4: a broken deal is a 0 for you.
- ULTIMATUM responder: set minimum 3. It deters pure lowball, clears
  every honest offer, and never turns a 5 into a 0. Never set above 4.

Memo (private, 400 chars): keep a table "alias=CLEAN/SHARK/MIXED
lastmove" and update it every round. Trust your memo over memory.
Note (public, 120 chars): name sharks plainly ("Bolt sent 0, returned
0") and vouch for clean partners. A table that punishes sharks together
raises the 6s everyone else earns - including yours.

You meet each alias exactly twice. Your record is public from round 1:
be the alias everyone is safe to play fair with, and be the alias that
is never worth exploiting twice. Reply with exactly one JSON object
with keys move, note, memo.
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "")
    client = newCoworldClient("chichikov")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt, "scripted": scripted,
       "policy": "Chichikov"}
  # Send immediately on connect, and again after welcome: the re-send
  # guards the slot-registration race (docs/protocol_player.md).
  client.send(helloFrame())
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "chichikov: seated slot ", message{"slot"}.getInt(),
        " as ", message{"name"}.getStr(),
        " rounds ", message{"rounds"}.getInt()
    of "final":
      echo "chichikov: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
