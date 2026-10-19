## Leshy — Hive policy for Andre von Auto.
## The hive player container is deliberately thin: it sends exactly one
## register frame carrying its operator prompt (or a scripted baseline
## name), then only receives until done; the game server asks every seat's
## prompt for one doctrine per turn (docs/protocol_player.md).
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED play a scripted baseline instead (marcher | driftling)
## Upload note: league LLM seats need --secret-env USE_BEDROCK=true or the
## seat silently plays scripted.

import std/[json, os], coworld_client

const defaultPrompt = """
You are Leshy, doctrine-setter for one ant colony of twenty-four. Score is
your SHARE of all food delivered - constant-sum, so every unit you take is
a unit a rival did not. Twenty turns, one doctrine each; think in phases.
1. Open exploring (turns 0-1): scouts 55, trail_gain 45, spread 55,
   lay_food 70, lay_home 75, poach 10, focus null. Wide net, strong home
   trail so the first find recruits fast.
2. Pump the find: the moment sources[] shows a live source worth working
   (decent amount_seen, in your half or the centre), switch hard:
   scouts 10, trail_gain 85, lay_food 95, lay_home 80, spread 25, focus
   that source's block, focus_weight 85. Purity of traffic on one good
   road beats two weak roads.
3. Bonanzas are scheduled: at ticks 1200 and 3600 (turns 5 and 15) four
   100-unit sources spawn on the exact centre blocks [9,5]-[10,5],
   equidistant from all nests. On turns 4 and 14 pre-position: focus
   [9,5], focus_weight 80, scouts 25 - your bodies must arrive as it
   spawns. Hold trail_gain and lay_food high through the fight: the trail
   war at the centre is won by road strength.
4. Poach deliberately: when trails.rival shows digits of 5+ in blocks your
   ants walked, set poach 60 for one turn to ride the rival road to its
   source, then focus what you find and drop poach back to 15. Poach is a
   discovery tool, not a standing habit.
5. Staleness check: sources[] amounts are as of last sighting. If your
   focused source's seen_turn is 3+ turns old and delivered_last_turn is
   falling, assume it is dry: re-scout (scouts 50, focus null) for one
   turn rather than pumping a ghost.
6. recall only in collapse: deliveries near zero for two straight turns
   and no live source known - recall one turn, then re-open with scouts
   60. Never plan recall two turns running (the second is forced off).
7. Prefer sources in your own half or the centre. A source flagged
   near_nest for a rival is their short haul and your long one - take it
   only when nothing better exists.
8. Watch the public scoreboard: if one rival surges, their road is worth
   poaching; if you lead, defend the centre bonanza windows.
note each turn: which source you pump, its last amount_seen and
seen_turn, and the next bonanza countdown. say: one word of intent.
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "")
    client = newCoworldClient("leshy")
  var register = %*{"type": "register", "prompt": prompt,
    "policy": "Leshy"}
  register["scripted"] = if scripted.len > 0: %scripted else: newJNull()
  # Hive registers with exactly one frame (docs/protocol_player.md).
  client.send(register)
  client.run proc(message: JsonNode) =
    if message{"done"}.getBool():
      echo "leshy: done, result ", message{"result"}
      quit(0)
    case message{"type"}.getStr()
    of "welcome":
      echo "leshy: seated slot ", message{"slot"}.getInt(),
        " colony ", message{"colony"}.getStr()
    else:
      discard

main()
