# Fielding a policy

A policy is a prompt. Upload this image with a `PLAYER_PROMPT` and the game container asks the model, once per turn, for one standing order:

    coworld upload-policy coworld-daycare:latest --name my-daycare \
      --run /bin/daycare-player \
      --secret-env PLAYER_PROMPT="<your strategy, for BOTH roles>" \
      --secret-env USE_BEDROCK=true

`PLAYER_SCRIPTED=caretaker` or `PLAYER_SCRIPTED=stubborn` plays a built-in baseline instead, deterministically, with no LLM.

## The reply schema
Exactly one JSON object whose first character is `{`.

Parent: `{"job":"provide","fruit":"banana","guess":"banana","hunch":"it only ever reaches for bananas","notes":"turn 3 it walked over an apple twice"}`

Child: `{"job":"show","fruit":"banana","hunch":"I will stand under the banana tree until it notices","notes":"apples keep arriving"}`

| field | rule |
|---|---|
| `job` | must be in THIS ROLE's enum; anything else is an invalid reply |
| `fruit` | `apple` or `banana`; required for parent `provide`/`stock` and child `seek`/`show` |
| `guess` | `apple` or `banana`; REQUIRED from the parent every turn. A guess that disagrees with the fruit being delivered is accepted as written -- testing a hypothesis by delivering the other species must stay expressible |
| `hunch` | at most 80 characters, truncated on rune boundaries. SPECTATORS ONLY -- the other seat never sees it |
| `notes` | at most 240 characters. PRIVATE -- returned only to you, next turn |

Extra keys are ignored. An invalid reply is retried ONCE with a hint, then that seat plays the `caretaker` order for the turn and the `order` event records `"source":"fallback"`.

## The behaviour summary the parent gets
The sim computes it, so it is identical for every policy: per species, `adjacentTicks`, `reachAttempts`, `reachFails`, `groundPasses` (walked over without eating), `ate` and `carriedTicks`, for the last turn AND cumulatively, plus `cellsWalked` and `idleTicks`. Failed reaches at a tall tree are the purest signal -- the child cannot pick them, so reaching there is pure desire. The child gets the mirror-image summary about the parent's deliveries, and its OWN preference; it never sees the parent's guess.
