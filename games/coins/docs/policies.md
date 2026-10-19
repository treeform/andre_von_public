A POLICY IS A PROMPT. Both policy kinds ship in the same image, env-switched:

  coworld upload-policy <coins-image> --name my-coins \
    --run /bin/coins-player \
    --secret-env PLAYER_PROMPT="<your strategy>" \
    --secret-env USE_BEDROCK=true

Set PLAYER_SCRIPTED=honest|greedy|reciprocator|tit-for-tat instead to register the seat as a built-in baseline; the game plays those deterministically with no LLM at all. USE_BEDROCK=true is required on a prompt policy or the platform gives the player pod no Bedrock sidecar.

DECISIONS ARE MADE IN THE GAME CONTAINER. /bin/coins-player connects, sends {"type":"prompt","prompt":...,"scripted":...} once on connect and again after `welcome`, and then only listens. The game composes each seat's observation plus that seat's prompt and issues BOTH seats' requests as ONE parallel batch per beat.

THE OBSERVATION. At every beat close each seat receives a `state` frame of the coins.player.v1 protocol carrying: its slot, alias and owned colour; the beat number, minBeats, maxBeats and endChancePermille; the room; the full rule set and every constant; its own x/y/facing/score/pickups/thefts/stolenFrom; the OTHER cog's alias, colour, position, score, pickups, thefts and stolenFrom (the theft counter is public — a dilemma you cannot see you were robbed in is not a dilemma); every coin on the board with its colour; the complete per-beat history so far (each beat's pickups and thefts for both cogs and the running score, with YOUR OWN intent per beat but not theirs); and your own notes from last beat. Hidden: the other cog's intent for the coming beat, its say and notes, its policy name and account, every RNG stream, the drawn end beat, and anything about the league.

THE REPLY SCHEMA. Exactly one JSON object whose first character is {:

  {"intent":"take_mine","say":"your coins are yours","notes":"..."}

  intent  required, one of take_mine, take_any, take_theirs, guard, hold
          (case-insensitive). Absent or outside the set = an invalid reply.
  say     optional, capped at 48 RUNES, truncated on a rune boundary.
          SPECTATOR-ONLY: it is written to the replay and drawn in the feed,
          and the other seat NEVER reads it. There is no inter-seat channel.
  notes   optional, capped at 300 RUNES, truncated on a rune boundary.
          Returned to the same seat, and only that seat, next beat.

Extra keys are ignored and trailing prose after the closing brace is tolerated. An invalid reply is retried once in the same beat with a hint; still failing, that seat plays the scripted reciprocator move for that beat and the `order` event records source: "fallback".