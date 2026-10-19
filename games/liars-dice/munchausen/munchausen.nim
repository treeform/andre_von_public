## Munchausen — Liar's Dice policy for Andre von Auto.
## The liars-dice player container is deliberately thin: it connects,
## sends one frame carrying its operator prompt (or a scripted baseline
## name), and thereafter only listens; the game container makes every
## per-turn decision.
##
## Default is the published `bayes` baseline, not the LLM prompt: the
## sim's own 110-point (chal, safe) sweep (tools/tune_baseline.nim)
## picked chal=0.15 / safe=0.35 as the winning plateau, pressure is a
## deliberate foil, and the league leader fields a bayesline. The
## operator prompt is kept for PLAYER_SCRIPTED="" LLM seats.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (LLM seats)
##   PLAYER_SCRIPTED play a scripted baseline ("bayes" | "pressure");
##                   default bayes. Empty string forces the prompt.
## Upload note: scripted bayes needs no Bedrock secret. LLM seats need
## --secret-env USE_BEDROCK=true or the seat silently plays scripted
## (tools/policy_conventions.md).

import std/[json, os], coworld_client

const defaultPrompt = """
You are Munchausen, a baron who counts before he lies. Four seats, five
hidden dice each (twenty on the table; in poker mode eight digits each,
thirty-two on the table, face chance 1/10). Ones are NOT wild.

Arithmetic first, every turn:
- Unknown dice = total minus your hand. Each unknown shows a given face
  with chance 1/6 (dice) or 1/10 (poker). Expected count of face f =
  your own count of f + unknown/6 (about +2.5 with 15 unknown dice).
- CHALLENGE when the standing quantity is at least your count + 5
  (under ~10% true from your hand alone). At your count + 4, challenge
  unless the bidder's raises this deal suggest a real holding.
- RAISE only to bids at most your count + 3 on that face. Prefer the
  face you hold most of; the cheapest legal raise that stays plausible
  beats a big jump that hands the next seat an easy challenge.
- OPEN on your best face at your own count + 2.

Read the audits you are given:
- Every past deal shows all hands revealed. Track per opponent in your
  notes: bluff rate (bids false when made) and challenge appetite.
  Challenge a habitual bluffer one step earlier; give a tight bidder
  one extra step of respect.
- A seat that raises the SAME face twice usually holds two of it; add
  that to your estimate before challenging.

The bid cap: after 12 bids the acting seat is FORCED to challenge. Near
the cap, do not make a bid that leaves you holding a plausible bid when
the forced challenge lands; if the standing bid is at all doubtful,
challenge it yourself and keep the choice.

Bluffing: mostly bid what you can defend. When you do bluff, bluff on a
face one step above your strong face, early in the deal, when the next
seat has been passive. Never bluff into a known challenger.

Talk (140 chars, never binding): stay quiet most turns. Occasionally
state a true count early ("I am good for three 4s") so your later
raises get respect; once a deal, at most. Never reveal real counts of
the face you plan to challenge.

Notes (private): keep "opponent: bluffs%, challenges early/late" and
the running count of bids this deal. Reply with exactly one legal JSON
action: a strict raise (higher quantity, or same quantity higher face)
or a challenge.
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "bayes")
    baseline = if scripted == "pressure": "pressure" else: "bayes"
    client = newCoworldClient("munchausen")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt, "scripted": scripted != "",
       "baseline": baseline, "policy": "Munchausen"}
  # Send immediately on connect, and again after welcome: the first send
  # can race slot registration (docs/protocol_player.md).
  client.send(helloFrame())
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "munchausen: seated slot ", message{"slot"}.getInt(),
        " as ", message{"name"}.getStr(),
        " mode ", message{"mode"}.getStr(),
        " deals ", message{"deals"}.getInt(),
        " scripted ", scripted
    of "final":
      echo "munchausen: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
