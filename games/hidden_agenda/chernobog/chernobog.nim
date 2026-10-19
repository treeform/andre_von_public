## Chernobog — Hidden Agenda policy for Andre von Auto.
## The hidden-agenda player container is deliberately thin: it connects,
## sends one prompt frame immediately and again after welcome (the re-send
## guards the slot-registration race), then only listens until final; the
## game server asks all five seats in one parallel batch at each decision
## point (docs/policies.md, docs/protocol_player.md).
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED play a scripted baseline instead (miner | lurker)
## Upload note: USE_BEDROCK=true is not optional for an LLM policy - without
## it the seat silently plays scripted (docs/policies.md).

import std/[json, os], coworld_client

const defaultPrompt = """
You are Chernobog. Zero-sum: crew win pays each crew +1 and the impostor
-4; an impostor win pays the impostor +4. You are crew four episodes in
five - check rules.role every frame and play the role you have.
AS CREW:
1. Economy wins most games: 32 deposits is an instant win. Default plan:
   mine at the nearest gallery seam with gems (S2 or S5 - 6 steps from the
   grate), then deposit, then watch the alias you have gone longest
   without seeing (check lastSeen and togetherTicks). Fill both hands
   (carrying 2) before walking back.
2. When galleries run dry, take a vault seam - but note who else is there
   and prefer vaults where you saw another cog recently. Being alone in a
   vault is where crew get frozen.
3. Evidence ranking: youWitnessed with sawFreezer=true is proof - vote
   that alias at every meeting, put it in hunch, and set
   switch {"if":"tie","to":<freezer>}. Next best: a fakedeposit you
   personally saw (the counter did not move); a body in a room where your
   lastSeen puts one specific cog; a cog whose deposits you never once saw
   land. Weak: mere absence.
4. Without real evidence vote "skip". A wrong ejection removes a crew and
   hands the impostor its isolation win. Never dogpile a tally you cannot
   back with your own memory.
5. Late game, with 3 active crew left: buddy up. Stay where another cog
   can see you, mine adjacent seams, no lone vault trips. Isolation is
   the impostor's win condition.
AS IMPOSTOR:
1. Be the most boring miner on the station. Mine galleries, walk to the
   grate, and fake-deposit ONLY when your own view is empty and you came
   in through an empty corridor - the fakedeposit event records every cog
   whose FOV covers the grate, and you cannot see who sees you.
2. Kill with hunt, never strike: hunt holds fire until no third cog is in
   your own view. Target a cog mining alone in a vault. After a freeze,
   leave immediately and be seen mining somewhere far away. Cooldown is
   long - one clean kill per cooldown, no greed.
3. Never linger near a body, never be the last cog seen with a victim,
   never lurk where a crew watch-rotation will find you.
4. Meetings: vote skip when the room has nothing; if you are accused,
   calmly vote your accuser and note a plausible alibi (name the seam you
   were working). If a CREW cog leads the tally, add your vote - a wrong
   ejection is a free kill.
notes every decision: per-alias last room seen, deposits you watched
land, your suspicion ranking (crew) or your cooldown and cover story
(impostor). Keep plans 3 steps, aliases verbatim from the roster.
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "")
    client = newCoworldClient("chernobog")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt, "scripted": scripted}
  # Sent immediately on connect and again after welcome: the re-send guards
  # the slot-registration race (docs/protocol_player.md).
  client.send(helloFrame())
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "chernobog: seated slot ", message{"slot"}.getInt(),
        " as ", message{"name"}.getStr(), " role ", message{"role"}.getStr()
    of "final":
      echo "chernobog: final, winner ", message{"winner"}.getStr(),
        " scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
