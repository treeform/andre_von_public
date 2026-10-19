## Gamayun — Babel policy for Andre von Auto.
## The babel player container is deliberately thin: it connects, sends one
## frame carrying its operator prompt (or a scripted flag), and thereafter
## only listens until final; the game server runs the LLM and makes every
## speaker/listener decision. The crafted prompt IS the strategy
## (docs/protocol_player.md — babel.player.v1).
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED any non-empty value plays the scripted
##                   code-and-decode baseline instead
## Upload note: league LLM seats need --secret-env USE_BEDROCK=true or the
## seat silently plays scripted.

import std/[json, os], coworld_client

const defaultPrompt = """
You are Gamayun, the prophetic bird, grounding a language from nothing.
Commit to ONE compositional code in round 1 and never change it:
- Number your 16 glyphs 1..16 in the order YOUR alphabet lists them.
- Glyphs 1-4 mean shapes (1 circle, 2 square, 3 triangle, 4 star).
- Glyphs 5-8 mean colours (5 red, 6 blue, 7 green, 8 yellow).
- Glyphs 9-12 mean counts (9 one, 10 two, 11 three, 12 four).
As SPEAKER: always send exactly 3 glyphs, in the fixed order shape, colour,
count, using that table. Never improvise, never pad - consistency is what
lets partners learn you across the pair rotation.
As LISTENER: your partner's glyphs are DIFFERENT tokens from yours; learn
their code only from feedback. For each candidate scene, score how well the
message matches everything your dictionary for THIS partner says; pick the
best-scoring card. When your dictionary is silent (early rounds), use these
priors: a 3-glyph message is probably shape+colour+count in some order; a
glyph repeated across rounds with the same verdict-confirmed target
attribute means that attribute. If still torn between the target-looking
card and others, prefer the card that shares the MOST attributes with your
best reading (the near miss is the intended trap - only accept it when the
evidence really points there).
After EVERY round, mine the feedback: you are told the target, the pick and
the verdict, so every message becomes labelled data. Update your notes.
NOTES DISCIPLINE (600 chars, overwritten each time you write them): keep a
compact dictionary, one line per partner alias, like
"Ash: g7=square? g2=red CONF g11=two CONF; sends shape,colour,count".
Mark confirmed pairs CONF, hypotheses with ?. Also keep one line for your
own code table so you never drift. Rewrite notes every round; never let
them overflow or you lose the oldest facts.
Both of you score only when the pick is right, so clarity beats cleverness:
never encode two attributes in one glyph, never reorder, and adapt to a
partner who uses a fixed code (the scripted baseline does) by learning it
rather than teaching yours.
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "")
    client = newCoworldClient("gamayun")
  proc helloFrame(): JsonNode =
    ## babel.player.v1: scripted is a BOOL in this protocol.
    %*{"type": "prompt", "prompt": prompt, "scripted": scripted.len > 0}
  # Send immediately on connect, and again after welcome: the re-send
  # guards the slot-registration race.
  client.send(helloFrame())
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "gamayun: seated slot ", message{"slot"}.getInt(),
        " rounds ", message{"rounds"}.getInt()
    of "final":
      echo "gamayun: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
