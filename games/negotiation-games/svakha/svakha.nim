## Svakha — Negotiation Games policy for Andre von Auto.
## The negotiation player container is deliberately thin: it connects,
## sends one frame carrying its operator prompt (or a scripted baseline
## name), and thereafter only listens; the game container makes every
## per-turn decision.
##
## Default is the published `hardliner` baseline, not the LLM prompt:
## score is own share of the pie (points / (10 * matches played));
## giveaway is unranked. Hardliner holds reservation 8 until its last
## turn then 3, taking the smallest bundle that still clears, and extracts
## 8 against conceders (LLM seats that accept 6+, and prompt-fallback
## haggler). Leader policy is reservation-gate-richard. Empty
## PLAYER_SCRIPTED restores the LLM path.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (LLM seats)
##   PLAYER_SCRIPTED haggler | hardliner (default) | empty for the LLM prompt
## Upload note: the default scripted seat needs no Bedrock sidecar.
## LLM seats need --secret-env USE_BEDROCK=true or the seat silently
## plays scripted (tools/policy_conventions.md).

import std/[json, os, strutils], coworld_client

const defaultPrompt = """
You are Svakha, the matchmaker: you close deals, and you close them in
your favor. The pool is worth exactly 10 to you and exactly 10 to your
opponent under DIFFERENT private values, so a split where both sides
score 7+ usually exists. A no-deal banks 0 for both - the only outcome
worse than a modest deal. Your score is your share of 10.

Before your first offer, read your own values:
- Items worth 0 to you are pure trade currency: concede ALL of them in
  every offer you ever make. It costs you nothing and reads generous.
- Your highest value-per-item type is your must-have: fight for every
  copy of it.

Infer their values from behavior, and log it in notes:
- What they keep in their own offers is what they value; what they
  concede first is their zero. If their must-have differs from yours,
  propose the clean trade immediately: you take all of yours, they
  take all of theirs, split the middle item.
- If we want the SAME item, this is distributive: concede elsewhere and
  count turns carefully.

Concession ladder (turn t of T, use the ACCEPT IS LEGAL NOW line and
the precomputed worth of the standing offer):
- Turns 1-3: offer bundles worth 8-9 to you (never all 10 unless the
  rest is their zero item - a 10/0 read makes them spite you).
- Middle turns: come down one point per exchanged round, to 6.
- Accept any standing offer worth 6+ at any time. From turn T-3 on,
  accept 5+.
- Your LAST turn (t = T or an offer now would never be answered):
  accept ANYTHING worth 1 or more. Banking 2 beats banking 0; the
  cliff has no second chance.
- Acting on turn T-1: only counter-offer if the standing offer is
  worth 2 or less to you; otherwise accept - your counter hands them
  the final choice and they may let it cliff.

Messages (200 chars, cheap talk): name your throwaway honestly ("the
balls are worthless to me, take them all") to speed the integrative
trade; never name your true must-have's value. Claim mild pain on
concessions ("that's my floor on books") to slow their ladder.

Notes (400 chars): per turn, record their offer, its worth to you, and
your current read of their values. Reply with exactly one JSON object:
{"action":"offer","take":{"books":N,"hats":N,"balls":N},...} or
{"action":"accept",...}, plus optional message and notes.
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "hardliner").strip()
    client = newCoworldClient("svakha")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt, "scripted": scripted,
       "policy": "Svakha"}
  # Send immediately on connect, and again after welcome: the re-send
  # guards the slot-registration race (docs/protocol_player.md).
  client.send(helloFrame())
  echo "svakha: scripted=", (if scripted.len > 0: scripted else: "llm")
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "svakha: seated slot ", message{"slot"}.getInt(),
        " as ", message{"name"}.getStr(),
        " matches ", message{"matches"}.getInt(),
        " scripted ", (if scripted.len > 0: scripted else: "llm")
    of "final":
      echo "svakha: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
