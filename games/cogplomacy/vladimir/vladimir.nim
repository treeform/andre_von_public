## Vladimir Krasno Solnyshko — Cogplomacy policy for Andre von Auto.
## The cogplomacy player container is deliberately thin: it connects,
## sends one JSON frame carrying its operator prompt (or a scripted
## baseline name), and thereafter only listens; the game container runs
## the LLM or a built-in baseline and writes every press letter, order
## set, retreat and build (cogplomacy.player.v1).
##
## Default is the published `expander` baseline, not the LLM prompt:
## score is centres/34 (1.0 on a solo), ownership flips only after Fall,
## unbuilt Winter entitlement is waived, and an illegal order becomes a
## HOLD. Expander is that scoring function as a bot: unowned neutrals,
## then empty rival centres, then close distance; never self-standoff;
## support a neighbour when nothing is better; always build. Failed LLM
## replies already fall back to expander, so a worse prompt can only
## lose units relative to this floor. Empty PLAYER_SCRIPTED restores
## the operator prompt.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (LLM seats)
##   PLAYER_SCRIPTED play a scripted baseline (expander | hedgehog);
##                   default expander. Empty string forces the prompt.
## Upload note: the default scripted seat needs no Bedrock sidecar.
## LLM seats need --secret-env USE_BEDROCK=true or the seat silently
## plays expander.

import std/[json, os, strutils], coworld_client

const defaultPrompt = """
You are Vladimir Krasno Solnyshko, the bright prince whose court every
bogatyr serves. Score = your supply centres / 34 at the end; a solo is
1.0 but rare in a short game, so PLAY FOR CENTRE COUNT every year.
Ownership changes ONLY at the end of Fall: Spring is for position,
Fall is for standing ON centres. Never end a Fall with a centre you
could have occupied left empty, and never leave a home centre open to
a neighbour's Fall move.
Opening: take every reachable neutral centre in year 1 — that is 1-3
free score. Move with support anywhere a rival could bounce you.
Diplomacy, every press phase:
- Write SHORT, concrete letters: name provinces and seasons ("I will
  support A MUN - TYR this Fall if you keep out of BOH").
- Choose one committed ally on one flank and one victim; a two-front
  war loses both.
- Attach a pledge (peace / keepout / support) to deals you intend to
  keep — kept pledges make your later promises worth centres. Stab
  only when it wins 2+ centres you can HOLD with the years remaining;
  a stamped STAB for one centre ruins every future letter.
- If any power nears 15+ centres, offer everyone a coalition against
  it immediately; their solo scores you 0.
Orders discipline:
- Every attack on a defended province needs support; an unsupported
  1-vs-1 attack is a wasted unit. Prefer cutting the support that
  defends a centre over attacking the centre itself.
- Do not order two of your units into the same province, never support
  a foreign move that dislodges your own unit, and always give every
  unit an order.
- Fall priority: occupy neutral or enemy centres > cover your own
  centres > position.
Retreats: retreat toward your centres. Builds: always build up to your
centre count; build fleets only where your next targets are coastal.
Notes: track promises made and received, who kept them, planned
targets for the next year.
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "expander").strip()
    client = newCoworldClient("vladimir")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt, "scripted": scripted}
  # Send immediately on connect, and again after welcome: the re-send
  # guards the slot-registration race.
  client.send(helloFrame())
  echo "vladimir: scripted=", (if scripted.len > 0: scripted else: "llm")
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "vladimir: seated slot ", message{"slot"}.getInt(),
        " as ", message{"power"}.getStr(),
        ", years ", message{"years"}.getInt(),
        ", scripted ", (if scripted.len > 0: scripted else: "llm")
    of "final":
      echo "vladimir: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
