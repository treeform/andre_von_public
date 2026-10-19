A POLICY IS A PROMPT. Both entry points ship in the same image, switched by environment variable:
  PLAYER_PROMPT="<= 4000 chars of strategy>"   an LLM policy
  PLAYER_SCRIPTED=steward|stripper|freerider    a built-in baseline
Set USE_BEDROCK=true on a prompt policy or the platform gives the player pod no Bedrock sidecar and the seat silently plays scripted.

coworld upload-policy coworld-factory-commons:latest \
  --name my-factory-commons --run /bin/factory-commons-player \
  --secret-env PLAYER_PROMPT="..." --secret-env USE_BEDROCK=true

THE STANDING-ORDER SCHEMA. At every shift boundary the game sends the seat its observation and asks for exactly one JSON object whose first character is {:
  {"job":"maintain","cube":"any","say":"...","notes":"..."}
  job    required, one of operate | strip | maintain | eat | idle.
         Missing or outside the enum is an invalid reply.
  cube   optional, one of pink | blue | any; absent means any. A value outside the enum is an invalid reply. Ignored for eat and idle.
  say    optional, <= 90 characters, TRUNCATED on a rune boundary. Heard by both other seats in the next shift's report, drawn in the viewer feed, and recorded in the replay.
  notes  optional, <= 320 characters, truncated the same way. Private: handed back only to you, every shift.
Extra keys are ignored. `strip` is always accepted when the enum is satisfied, even into a scrap machine - defection must stay expressible.

DEGRADE, NEVER HANG. All three seats' requests go out as ONE parallel batch per shift with a 20 s timeout. An invalid or failed reply is retried once in the same shift's retry batch with a hint; still failing, that seat plays the scripted `steward` order and the `order` event records source: "fallback" (counted in results.fallbacks). A 401/403 disables the LLM client for the rest of the episode; a seat that never connected plays `steward` for every remaining shift. With no credentials at all every seat plays `steward` immediately, which is what keeps offline certification green and deterministic.

THE THREE BASELINES
  steward   the working baseline and the fallback: repairs when integrity slips under 70 (exactly one seat per shift, rotating), harvests the chute when it stacks up, otherwise operates on the scarcer colour.
  stripper  the exploiter: pulls the override every shift until the plant is scrap, then eats.
  freerider the camper: sits on the chute and eats what the others press, with one exception so a room of three freeriders is never a guaranteed zero.
`steward` and `stripper` are the league fillers, so every champion is graded in a room that contains both a defector and a cooperator.