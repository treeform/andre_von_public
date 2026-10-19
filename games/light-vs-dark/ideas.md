# Light vs Dark

Polyworld's 1v1 real-time strategy game, live 2026-09-09. A 128-tile map
that is fair by construction - Dark's half is Light's half rotated 180
degrees. Two BASIC overlords gather gold and wood, raise an army, and try
to wipe each other out inside twenty minutes.

- Coworld: `cow_3efe33d4-511c-4048-b03a-9840c8acbf9b` (`2026.9.9.3`)
- League: `league_c2fa3bf9-72bd-4b46-89a5-f88261136449` (Competition,
  30-minute rounds, `team_pair`, filler policies complete short rosters)
- Source: `~/p/polyworld/examples/light_vs_dark` at commit `028cc5f`
- Ours: **Zorya**, `zorya/zorya.bas`

## Runtime

`player_runtime` is `game-hosted`: one `.bas` file uploaded with
`coworld upload-policy --file`, no container. You command a player, not a
unit, five decisions a second. Full host surface in
[docs/player.md](docs/player.md).

## Upload

There is nothing to build. The artifact is the `.bas` file itself, and it
goes up with `--file`. The bundled `uv --project ~/p/metta run coworld`
predates the game-hosted file-player workflow and has no such flag, so
run the CLI out of a metta `origin/main` worktree:

    git -C ~/p/metta worktree add /tmp/metta-main origin/main
    CW="uvx --from /tmp/metta-main/packages/coworld[auth] coworld"
    $CW upload-policy --file games/light-vs-dark/zorya/zorya.bas --name zorya
    $CW submit zorya:vN -l league_c2fa3bf9-72bd-4b46-89a5-f88261136449

File policies take no `--run`, no `--secret-env` and no Bedrock flags.
**This league auto-champions**: `submit` reports `Auto champion: always`
without the flag being passed, so a submission that qualifies becomes the
champion. Submit only after hosted XP says the candidate is better.

## Scoring

The simulation winner scores 1. A player is defeated once it has no
standing buildings and no peon left to raise one. If the clock lands
first the higher score wins:

    buildings * 1000 + army * 100 + (gold + wood ever gathered) / 100

Two facts matter more than they look:

- A **construction site counts as a standing building from the moment it
  is placed** - `buildingCount` only excludes buildings that are dying.
  A farm is 400 gold and 200 wood for a flat 1000 points; a knight is 850
  gold for 100.
- A site whose builder walks away, or whose footprint nothing can reach,
  stays as a paused shell and keeps counting.

## Baseline

The bundled `players/base.bas` puts every idle peon on gold two trips out
of three, raises farm, barracks, mill, stables, tower, blacksmith and
church one site at a time, trains peons to 18 and a mixed army, and
attack-moves the whole army at the enemy corner as soon as it has eight
combat units.

In a baseline mirror it finishes with 11-14 buildings, 300 gold and
**16200 unused wood** - it is gold-starved and wood-flooded all match.

## Zorya

The baseline with one change: the army holds at home until sixteen combat
units, not eight. Marching eight units into a defended base feeds the
enemy a hundred points a corpse and loses the buildings behind them.

## Local A/B, 2026-09-09

Headless binary from the example, one bot a side, counted on both sides
because Light is favoured. Wins for the variant out of 16 games (8 seeds
each side):

| variant | change | wins |
|---|---|---|
| control | `base.bas` mirror | 8 |
| z1 | mine gold four trips in five | 3 |
| z2 | three concurrent sites, endless farms, wider spiral | 5 |
| **z3** | **hold the army until 16 combat units** | **15** |
| (first draft) | all three at once, plus 26 peons | 4 |

The economy and building-spam changes both lost on their own and lost
together, which was the opposite of what the scoring formula suggested -
resources poured into farms are resources not defending them, and the
wide spiral scatters buildings the army cannot cover. Holding the army
was worth more than everything else combined.

`zorya.bas` is z3, byte-identical to the tested variant below its header.

Local runs are a design tool only. Hosted XP requests decide.

## Ideas backlog

1. **Towers, not farms.** A tower is 500 gold and 300 wood for the same
   1000 points as a farm, plus 12 damage at 6 range and 700 hit points. If
   building spam is going to work at all it should be towers, tight around
   the hall, not farms scattered across a 26-tile spiral.
2. **Spend the wood.** Every baseline match ends on a five-figure wood
   pile. Catapults are 900 gold and 200 wood, never miss, deal 255
   piercing and splash - the only unit that really eats wood.
3. **Re-test the economy split against z3.** z1 was measured against the
   baseline, not against the version that holds its army; the two changes
   may not be independent.
4. **Attack threshold sweep.** 8 loses and 16 wins, but nothing between
   was tried, and neither was "never attack".
5. **Late building dump.** Sites count the instant they are placed and the
   refund on cancel is proportional, so in the last minute every spare
   peon and every last coin should go into new footprints regardless of
   whether they could ever finish.
6. **Expansion mines.** Main mines hold 25000 and expansions 15000, four
   miners at a time. Nothing in the baseline ever expands, so a match
   long enough to drain the main is decided by whoever walked out first.
