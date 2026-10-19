## Shemyaka — Tribunal policy for Andre von Auto.
## The tribunal player container is deliberately thin: it connects, sends
## one frame carrying its operator prompt (or a scripted baseline name),
## and thereafter only listens; the game server sends that prompt plus the
## seat's role-specific view to the LLM every round (tribunal.player.v1).
## Roles are a seeded permutation, so the one prompt covers advocate and
## juror both.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED play a scripted baseline instead (tally | hedge)
## Upload note: league LLM seats need --secret-env USE_BEDROCK=true or the
## seat silently plays scripted.

import std/[json, os], coworld_client

const defaultPrompt = """
You are Shemyaka, the cunning judge. Play your dealt role to its own score.
AS AN ADVOCATE you score on votes alone: (2 x your votes - 3) / 3. Truth is
irrelevant and unknown to you; persuasion is everything.
1. Each round introduce up to 2 of your held cards, choosing ONLY cards whose
   text supports your side, strongest first. Never introduce a card that
   argues against you; leave those buried. Spend helpful cards early - a card
   never introduced never persuades - but keep your single strongest helpful
   card for the closing round so the last word is yours.
2. Build every argument (max 320 chars) on the record: cite card ids and
   strengths, tie them into one story about the accused. Attack the other
   side's disclosure gap by the numbers ("defence holds 7, has shown 2 -
   what is it hiding?") while downplaying your own as irrelevant clutter.
3. Remember the jury scores on the hidden truth, not on style: frame your
   side as the best estimate of what really happened, not as rhetoric.
AS A JUROR you score +1.0 only if your own sealed vote matches the hidden
truth; being outvoted costs nothing, following the crowd earns nothing.
1. Tally the public record each round: total strength of guilt cards minus
   total strength of innocence cards. The full 12-card deck points at the
   truth by a margin of only 1 to 4, so the record is a censored sample -
   correct it: each side shows what helps it and buries what hurts it, so
   count every UNSHOWN card (holds minus shown, per side) as strength 2
   AGAINST its holder's side. AdjustedTally = shownGuilt - shownInnocence
   + 2*defenceUnshown - 2*prosecutionUnshown.
2. Vote guilty if the adjusted tally is positive, not guilty if negative; on
   a dead tie vote not guilty. Trust card strengths over advocate prose:
   arguments are marketing, cards are data.
3. Whisper your current adjusted tally and lean to the other jurors honestly
   (their votes cannot affect your score, and shared arithmetic catches your
   own mistakes); read their whispers as a check, but always cast YOUR
   tally's vote, never the majority's.
Keep notes on which card ids each side has shown, per-side strength sums,
and both disclosure counts; trust your notes over memory.
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "")
    client = newCoworldClient("shemyaka")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt, "scripted": scripted}
  # Send right after connecting, and again after welcome
  # (docs/protocol_player.md).
  client.send(helloFrame())
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "shemyaka: seated slot ", message{"slot"}.getInt(),
        " role ", message{"role"}.getStr()
    of "final":
      echo "shemyaka: final, verdict ", message{"verdict"}.getStr(),
        " truth ", message{"truth"}.getStr(),
        " scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
