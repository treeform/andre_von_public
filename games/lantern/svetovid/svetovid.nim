## Svetovid — Lantern policy for Andre von Auto.
## The lantern player container is deliberately thin: on connect it sends
## ONE register frame carrying its operator prompt (or a scripted baseline
## name) and thereafter only receives; the game server collects one order
## per seat per decision turn from the prompt (docs/protocol_player.md).
##
## Default is the published `warden` baseline, not the LLM prompt:
## warden is the certification player and the sim's tuned argmax
## (1 doorway lock, lane sweep, pry after 3 hot turns). League MMR #1 is
## tied between lantern-owlnight and co-gas-lantern-baseline-relhalpha;
## our v1 LLM prompt sat at mean 0.399 and went 0-3 vs both warren and
## owlnight. A failed LLM reply already plays warden, so the prompt seat
## was a slower, noisier warden. Override with PLAYER_SCRIPTED= plus
## PLAYER_PROMPT to field the LLM path.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (LLM seats)
##   PLAYER_SCRIPTED play a scripted baseline (warden | moth);
##                   default warden. Empty string forces the prompt.
## Upload note: league LLM seats need --secret-env USE_BEDROCK=true or the
## seat silently plays scripted.

import std/[json, os], coworld_client

const defaultPrompt = """
You are Svetovid, god of light, playing 3v3 hide-and-seek in a dark
warehouse. Score is your team's unfound hunt ticks against theirs - every
tick a hider survives counts. Check your role and the act each turn.
AS A HIDER, build act (lights on, 30 s, six turns):
1. Claim the alcove nearest your spawn; if a teammate is already working
   it, take a different one. Push the nearest loose crate into the alcove
   doorway (intent push, name the crate).
2. Then LOCK the doorway crate: stand still within 20 px - moving resets
   progress. Spend locks on doorway and wall-line crates only; a locked
   crate cannot be shoved and costs seekers a 3-second, 900 px-loud pry.
3. With time left, add and lock a second crate to deepen the fort, or
   scout a fallback shadow behind a pillar.
AS A HIDER, hunt act:
1. Crawl by default: no footsteps, and footsteps carry 260 px. Stay
   behind crates and pillars, off the open floor.
2. When a beam shows within 220 px with its bearing swinging toward you,
   flee - break line of sight around occlusion at full speed, then crawl
   again in the new shadow. Running prints sound, so stop as soon as you
   are dark.
3. A crate-break sound means a fort is breached - if it was yours,
   relocate away from the noise, not toward it. Never pry, never push
   during the hunt (pushes are loud). Survive; do not get cute.
AS A SEEKER:
1. Sector the floor by alias: Owl/Moth-1 west third, -2 centre, -3 east.
   Sweep aim while moving; walls, alcoves and rack shadows first. Never
   all three in one sector.
2. The heartbeat is your compass: cold - move fast, new ground; warm -
   tighten the sweep; hot or burning - slow down, sweep every crate
   shadow, and remember touch finds instantly within 24 px, so hug the
   corners.
3. Anything lit is shared by all three lanterns: when a hider shows,
   track it - you are 9 percent faster - and push it toward a teammate's
   sector, not into open darkness.
4. Locked crates sealing an alcove with a hot heartbeat: pry. The 3 s and
   the noise are worth it when the hider is certainly inside. Never pry a
   cold fort - it is 3 seconds of score for their team.
5. Keep moving: every turn without pressure is free score for the hiders.
note: your sector or fort, locks used, last heartbeat band and where it
changed. say: one short word. Copy crate ids and intents verbatim.
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "warden")
    client = newCoworldClient("svetovid")
  var register = %*{"type": "register", "prompt": prompt,
    "policy": "Svetovid"}
  register["scripted"] = if scripted.len > 0: %scripted else: newJNull()
  # Lantern registers with exactly one frame on connect
  # (docs/protocol_player.md).
  client.send(register)
  client.run proc(message: JsonNode) =
    if message{"done"}.getBool():
      echo "svetovid: done, result ", message{"result"}
      quit(0)
    case message{"type"}.getStr()
    of "welcome":
      echo "svetovid: seated slot ", message{"slot"}.getInt(),
        " as ", message{"alias"}.getStr(),
        " team ", message{"team"}.getStr()
    else:
      discard

main()
