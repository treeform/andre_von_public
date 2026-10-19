A POLICY IS A PROMPT. Every seat runs the same image. Set PLAYER_PROMPT to a strategy in plain English and the seat becomes an LLM seat; set PLAYER_SCRIPTED=reciprocator|hoarder and it plays that published baseline. A seat that sets neither plays reciprocator.

  coworld upload-policy <image> --name my-gift-policy \
    --run /bin/gift-refinements-player \
    --secret-env PLAYER_PROMPT="<your strategy>" \
    --secret-env USE_BEDROCK=true

THE CADENCE. You do not steer tick by tick. Once per round (60 ticks) the game sends your seat the observation below and asks for ONE standing order; a deterministic kernel walks and beams it for you for the next 60 ticks. All six seats are asked at the same moment, in one parallel batch.

THE ORDER, one JSON object whose first character is {:
  job      "collect" | "meet" | "hold" | "evade"   (required)
  target   one of the five OTHER cog aliases, or null; required when job is
           "meet" or gift > 0
  gift     integer 0..10, beams to fire at target this round (absent = 0;
           out of range is clamped and the order records clamped: true)
  consume  "now" | "end" | "never"   (absent = "end")
  say      <= 80 characters. SPECTATOR-ONLY: it is drawn in the viewer feed
           and recorded in the replay, and is NEVER delivered to another seat.
  notes    <= 320 characters, private to you, handed back next round.
Anything else is ignored. A reply that is unparseable, names an unknown job or
alias, targets itself, or omits a required target is retried once and then the
seat plays the reciprocator order for that round.

THE OBSERVATION. Your cell, your three token counts, your lowest held level,
your score, your beam budget and your last order; for EVERY other cog its
alias, cell, distance, whether it is hittable right now and in which
direction, its score, the running youGave / gaveYou / net counts between you
and it, the round it last gave to you and what it banked last round; every
loose raw token; the global gift ledger (last 16 gifts) and bank tape (last 8
consumes); your own per-round history; your notes; and the full rule block.
HIDDEN: every other cog's INVENTORY, its order, its notes, its prompt and its
policy name. You know what somebody banked. You do not know what they are
holding.