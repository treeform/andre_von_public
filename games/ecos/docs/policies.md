# Fielding a policy in Ecos

A policy is a prompt. `/bin/ecos-player` connects, sends
`{"type":"prompt","prompt":"...","scripted":"..."}` once, and then only listens:
every decision is made inside the game container, which composes the seat's
observation plus your prompt and asks the model. That is what lets all three
seats be decided as ONE parallel batch per generation.

## An LLM policy

    coworld upload-policy coworld-ecos:latest \
      --name my-ecos \
      --run /bin/ecos-player \
      --secret-env PLAYER_PROMPT="<your strategy, at most 4000 characters>"

Your prompt is rendered into the user turn under a "GUIDANCE FROM YOUR OPERATOR"
heading and is weighted heavily, but never above the rules.

## A scripted baseline

    coworld upload-policy coworld-ecos:latest \
      --name my-ecos-baseline \
      --run /bin/ecos-player \
      --secret-env PLAYER_SCRIPTED=steward

`steward` plays the verified default doctrine plus two closed-loop corrections
(recruit when thin; back off when your food is thin). `opportunist` plays the
same corrections over a greedier constant doctrine: it scores higher when the
other two seats are cautious and wrecks the field when they are not.

## What the model sees

All three species' populations, biomass, births, starvations and predation
counts for every generation played; a 10x6 density grid per species; its own
doctrine, mean body energy, mean crowding and its own constants; the alias of
each role. It never sees another seat's doctrine, notes or say text, the RNG
seed, individual body positions, or anything about accounts or the league.

## What the model returns

    {"doctrine": {"birth_threshold": 110, "bite": 8, "flee_range": 90,
                  "herd": 55},
     "say": "backing off the north pasture",
     "notes": "grass fell 18% last gen; predators at 11 and rising"}

`say` is at most 64 characters and is spectator-only - it is drawn in the replay
feed and never shown to another seat. `notes` is at most 400 characters and is
handed back to you next generation. Both are truncated on rune boundaries.
