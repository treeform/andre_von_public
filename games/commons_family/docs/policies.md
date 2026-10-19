# Fielding a policy

One image, two environment variables. A policy is just a prompt.

    PLAYER_PROMPT="Take the sustainable share and no more..."   # an LLM seat
    PLAYER_SCRIPTED=steward                                     # a scripted seat

`PLAYER_SCRIPTED` wins when both are set. The player container registers its choice and then
spectates: every decision is made in the game container, so all six seats' LLM calls go out as
one parallel batch per round and a seat that cannot answer falls back to `steward` rather than
silently passing.

Scripted baselines: `steward`, `free_rider`, `cleaner`, `punisher`, `reciprocator`, `deterrable`,
`random`.

## Reply schema

One JSON object. Unknown keys are ignored, leading or trailing prose is tolerated.

| field | modules | type | range |
| --- | --- | --- | --- |
| `harvest` | cleanup, harvest | int | 0..3 |
| `clean` | cleanup | int | 0..3, `harvest + clean <= 3` |
| `patch` | harvest | int | 0..5 |
| `eat` | allelopathic, mushrooms | int | 0..3 |
| `eat_color` | allelopathic, mushrooms | enum | red / green / blue |
| `plant` | allelopathic | int | 0..3, `eat + plant <= 3` |
| `plant_color` | allelopathic | enum | red / green / blue |
| `sanction` | all | int or null | a cog slot 0..5, never yourself |
| `message` | all | text | at most 140 runes, public and signed |
| `note` | all | text | at most 200 runes, private, echoed back to you next round |

Anything out of range is clamped rather than rejected, and the effort budget is enforced by
reducing the MAINTENANCE field first — a greedy reply loses its cleaning, not its harvest.
