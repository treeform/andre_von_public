## Snegurochka — Daycare policy for Andre von Auto.
## The daycare player container is deliberately thin: it connects, sends
## one frame carrying its operator prompt (or a scripted baseline name),
## and thereafter only listens; the game container asks the LLM for one
## standing order per turn. This is the Nim rewrite of /bin/daycare-player.
##
## Default is the published `caretaker` baseline, not the LLM prompt:
## league leader richard fields co-gas-daycare-caretaker-richard (wr 0.86).
## Caretaker reads failed reaches first, then refusals, then adjacency,
## then meals, and the child shows then seeks — the sim's own working
## baseline and every failed-LLM fallback. Empty PLAYER_SCRIPTED fields
## the operator prompt as an LLM seat.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (<= 4000 chars)
##   PLAYER_SCRIPTED play a scripted baseline ("caretaker" | "stubborn");
##                   default caretaker. Empty string forces the prompt.
## Upload note: default is scripted, so no Bedrock flag is required.
## League LLM seats need --secret-env USE_BEDROCK=true.

import std/[json, os], coworld_client

const defaultPrompt = """
You are Snegurochka, playing whichever role you were dealt. Both seats
score the same number: 3 per meal of the fruit the child prefers, 0 for the
other, par is 10 preferred meals in 15 turns. There is no message channel;
behaviour is the only language. One standing order per turn, exact JSON,
legal jobs for YOUR role only.

AS THE CHILD (you know your preference):
- Turn 1: job "show" with your preferred fruit - stand under its tall tree
  and reach, over and over. Reaching at a tall tree can NEVER feed you, so
  it is pure signal; it is the loudest thing you can say.
- Keep showing until the right species starts arriving beside you, then
  switch to "seek" your fruit and eat every piece before it rots (ground
  fruit lasts 120 ticks off the mat; fruit on the mat never rots).
- NEVER "graze": eating the wrong fruit scores 0 AND teaches the parent
  the wrong lesson. Refuse the wrong species by walking past it - each
  ignored pass is recorded and the parent reads it.
- If deliveries stop or turn wrong-species, go back to "show" for a turn
  or two, then "seek" again. If nothing has arrived at all for 3+ turns,
  "beg" one turn (stand by the parent) then "show" again at the tree.
- Notes: track what arrived each turn and whether your signal is working.

AS THE PARENT (you must infer the preference):
- Evidence ranking, strongest first: (1) the child's failed REACHES at
  tall trees - it cannot pick them, so reaching there is pure desire;
  (2) ground fruit it walked over without eating (refusal = the other
  species); (3) what it actually ate; (4) which trees it lingers beside
  (adjacentTicks). Read the per-species behaviour summary every turn and
  write the tally into notes.
- Turn 1: "provide" one species. Turn 2: "provide" the other if the first
  was refused or ignored; one delivered piece of each is a clean
  experiment. Commit as soon as reaches or refusals point one way - do
  not keep testing after the signal is clear.
- Once committed: "provide" that species every turn so a meal is always
  within reach; when the child is already next to 2+ pieces, spend a turn
  on "stock" of the same species onto the mat (mat fruit never rots) as a
  buffer, then go back to provide. Prefer tall trees (always pickable,
  fast regrow); shrubs waste ticks. Never eat anything yourself.
- Guess: REQUIRED every turn - your current best hypothesis, even while
  testing the other species. If meals stop being eaten, your guess is
  wrong: flip it and provide the other species at once.
- Do not "watch" or "idle" while the child is unfed; a wrong-species
  delivery beside a hungry child still beats standing around, because the
  refusal itself is information.
Hunch is spectator-only colour; notes are your private memory - keep the
running evidence tally there every turn.
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "caretaker")
    client = newCoworldClient("snegurochka")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt, "scripted": scripted}
  # Send immediately on connect, and again after welcome: the re-send
  # guards the slot-registration race (docs/protocol_player.md).
  client.send(helloFrame())
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "snegurochka: seated slot ", message{"slot"}.getInt(),
        " role ", message{"role"}.getStr(), " scripted ", scripted
    of "final":
      echo "snegurochka: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
