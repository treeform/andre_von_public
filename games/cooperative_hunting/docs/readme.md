# Cooperative Hunting

**Six hunters share a 32x32 tile forest and take animals by standing on the
right cardinal sides of them at the same moment.** A rabbit falls to one
hunter. A boar needs two hunters on perpendicular sides, a stag two on
opposite sides, a moose any three, an elephant all four. Everyone who was on
a side when the animal fell scores the full value.

That is the whole game, and it is the assurance problem in a forest: rabbits
are a guaranteed +1, an elephant is +18 *each* -- but only if four hunters
commit to the same animal on the same tick. A half-formed ring gets trampled
(-30 energy) or gored (-10 energy and a shove) and scores nothing.

## Variants

| id | rounds x ticks | what is different |
| --- | --- | --- |
| `staghunt` | 3 x 960 | the base world |
| `coop-mining` | 3 x 960 | no animals; iron is solo, gold needs two hunters within a 3-tick window |
| `lbf` | 3 x 960 | hunters and food carry levels; adjacent levels must sum to the food's level; reward is split |
| `predator-prey` | 4 x 720 | three seats hunt, three forage; roles alternate each round; tall grass hides foragers |

## Scoring

`results.scores[slot]` is the sum over rounds of everything that seat's
captures were worth. Higher is better and no term is ever negative -- trample
and gore cost energy, never score. The league ranks by that number.

## Policies

Both champion policies are prompts. A seat registers either a `PLAYER_PROMPT`
(the game composes an observation every 15 s, asks the model what animal to
commit to and from which side, and a controller walks the hunter there tile by
tile) or a `PLAYER_SCRIPTED=<name>` baseline (one of eight compiled hunters
shipped in the same image). Same image, same entrypoint, switched by env.

## FAQ

**How do I connect a player?** Read `COWORLD_PLAYER_WS_URL` from the
environment and speak the sprite_v1 player protocol; see
`game.protocols.player` and the protocol page.

**When does my player exit?** When the episode ends and the game closes the
connection. Catch the error on a dead socket and exit 0.
