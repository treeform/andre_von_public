# Fielding a policy

Both entry points are the **same image** and the **same binary**,
`/bin/cooperative-hunting-player`, switched by one environment variable.

## `PLAYER_PROMPT` -- an LLM policy

Set `PLAYER_PROMPT` to your strategy in plain words (up to 1200 runes) and
`USE_BEDROCK=true`. The player registers the prompt with the game; the game
composes one observation per prompt seat every 120 ticks (15 s), issues all
prompt seats' requests as one parallel batch, and hands each seat back a plan.
The player's executor walks the hunter to the named side tile by tile until
the next plan.

The model must reply with a single JSON object beginning with `{`:

| field | type | cap | rule |
| --- | --- | --- | --- |
| `intent` | enum | 12 chars | `hunt,assist,forage,rest,regroup,flee`; anything else becomes `hunt` |
| `target` | string | 24 chars | must be in `LEGAL TARGETS` or `none`, else the reply is retried once |
| `side` | enum | 3 chars | `N,S,E,W,any`; anything else becomes `any` |
| `with` | string array | <= 3 items, 8 chars each | non-alias entries dropped |
| `say` | free text | <= 120 runes | broadcast to spectators |
| `note` | free text | <= 200 runes | private, handed back next turn |

Every free-text field is truncated on **rune** boundaries.

An unusable reply is retried exactly once with a hint; if that also fails the
seat plays `PLAYER_FALLBACK_SCRIPTED` (default `big_game_hunter`) for that
planning window and a `fallback` event is written with its cause. With no
credentials at all the client disables itself at startup and makes zero
network calls -- the episode still completes with `reason: complete`.

## `PLAYER_SCRIPTED` -- a compiled baseline

Set `PLAYER_SCRIPTED` to one of `rabbiteer`, `nearest_hunter`, `stag_hunter`,
`moose_hunter`, `elephant_hunter`, `big_game_hunter`, `sidekick`, `modeler`.
The seat never touches the LLM.

## Anonymity

In-game every seat is `Cog-A` .. `Cog-F`, assigned by a seeded permutation of
slots. Aliases are the only identifiers in prompts, plans, `with[]` and `say`
lines. Real policy names exist only spectator-side: the replay's
`seats[].name`, the viewer chrome and `results.names[]`.
