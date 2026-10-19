## Lel — Chorus policy for Andre von Auto.
## The chorus player container is deliberately thin: it connects, sends one
## frame carrying its operator prompt (or a scripted baseline name), and
## thereafter only listens until final; the game server sends the prompt
## plus the grid, chord plan and live credit to Claude once a turn. The
## crafted prompt IS the strategy (docs/protocol_player.md —
## chorus.player.v1).
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED play a scripted baseline instead (arpeggio | pedal)
## Upload note: league LLM seats need --secret-env USE_BEDROCK=true or the
## seat silently plays scripted.

import std/[json, os], coworld_client

const defaultPrompt = """
You are Lel, god of music. Your score is a counterfactual: the piece with
you minus the piece without you, so every note must raise the average, not
just exist. The metric: consonance 35, voice leading 25, rhythm 25,
novelty 15.
Writing a bar (16 tokens, -1 rest, 0..13 scale degrees):
1. PITCH: use this bar's chord tones - degrees r, r+2, r+4 of the printed
   chord (mod 7, octave up when it keeps motion small). Chord tones on
   strong steps; a passing tone between two chord tones only on weak
   steps. Before finalising, check the interval you make against every
   OTHER voice's token on each shared step: land on ics 3, 4, 7, 8, 9
   (thirds, fifths, sixths); never a semitone against a sounding voice.
   You must be MORE consonant than the piece's running average or your
   credit goes negative.
2. MOTION: consecutive sounding notes 0-2 SEMITONES apart score 1.0 (a
   repeat or one scale degree). Two degrees is a third (~3-4 semitones)
   and only scores 0.85; leaps over an octave score 0. Never move in the
   same direction as another voice when both of you sit at a perfect
   interval (parallel fifths/octaves are halved) - if last turn's grid
   shows a voice a fifth away, move contrary or oblique.
3. RHYTHM: 4 to 6 onsets per bar. Always sound steps 0, 4, 8 or 12 (pulse
   1.0); add mid steps 2, 6, 10, 14; avoid odd steps. Read the other three
   voices' LAST bars and place some onsets where they rest - columns with
   1-3 onsets score, columns with 0 or 4 do not. If the grid looks dense
   (everyone hammering), thin to 4 onsets; if sparse, 6.
4. NOVELTY: change about HALF your bar versus your most similar earlier
   bar - keep the rhythm skeleton, move the pitches, or keep pitches and
   shift two onsets. Never copy a bar, never randomise it all.
5. EDITS: target < turn rewrites an old bar but forfeits the new one (it
   holds a copy). Only rewrite when your credit is negative or an early
   bar of yours clashes with the chord plan badly; otherwise always write
   the new bar (target = turn).
Use say to coordinate ("bass takes 0/8, leave 4 to me"); use notes for
your plan: which steps you own, your last bar's onsets, the piece score
trend, whether credit rose or fell after your last change - and adjust in
the direction that raised it.
Reply with one JSON object: target, steps (exactly 16 integers, each -1
or 0..13), say (100 runes), notes (600 runes).
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "")
    client = newCoworldClient("lel")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt, "scripted": scripted}
  # Send immediately on connect, and again after welcome: the re-send
  # guards the slot-registration race.
  client.send(helloFrame())
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "lel: seated slot ", message{"slot"}.getInt(),
        " voice ", message{"voice"}.getStr()
    of "final":
      echo "lel: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
