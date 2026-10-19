# gods-of-the-arena tools

These games are `game-hosted`: the policy is a `.bas` file, so there is
no container to inspect and no wire log to extract. Local iteration runs
against the example's own headless binary instead.

Build it from a polyworld checkout at the commit the manifest names:

    cd ~/p/polyworld
    nim c -d:headless -d:release -o:/tmp/gota examples/gods_of_the_arena/gota.nim

Then use the shared ladder, which plays the candidate on both sides
because every one of these games has a favoured seat:

    nim r tools/polyworld_ladder.nim --game gota --binary /tmp/gota \
      --candidate games/gods-of-the-arena/<policy>/<policy>.bas \
      --baseline ~/p/polyworld/examples/gods_of_the_arena/players/base.bas \
      --seeds 12

Hosted results, replays and per-seat BASIC `PRINT` output come from the
platform: `coworld episodes`, `coworld episode-logs` and
`coworld replays`. `PRINT` goes to the owning player's private log only.
## Replay extractors (build against the hosted engine commit)
`gota_timeline.nim` and `gota_stats.nim` compile inside a polyworld worktree checked out at the
hosted coworld's source commit (replays refuse other game versions), from the polyworld root:
`POLYWORLD_DEPS=<dir of dependency symlinks> nim c --path:examples/gods_of_the_arena -d:headless -d:replayEvents -o:/tmp/gota_stats tmp/gota_timeline/gota_stats.nim`.
`gota_timeline PATH [heroId [interval [fromTick toTick]]]` prints structure, deaths, XP by source, CPU use, a hero track and its raw orders.
`gota_stats PATH` prints one stats row per hero; `gota_collate.nim <rows> <round rewards...>` turns rows from many replays into the policy comparison table (stats_<date>.md).

## gota_constants.nim: engine constants block

`nim r tools/gota_constants.nim <polyworld checkout> [policy.bas ...]` reads
the engine's `examples/gods_of_the_arena/content.nim` and emits a BASIC block
(hero attack reach/ticks/damage/hit points, every class ability's reach,
damage, heal, mana and cooldown by `class * 4 + slot`, item costs, tick and
potion/portal constants) between `' >>> engine constants` and
`' <<< engine constants` markers, stamped with the checkout's commit. With
policy files it replaces the block in place (or inserts it after the leading
comments). Regenerate whenever the hosted engine commit changes; the block is
guarded by `engineConstantsReady` so it costs one instruction a tick.

## gota_diag.nim: mechanics diagnostics (unit-test stages)

Nineteen isolated stages, each a hand-built situation inside the real
simulation: waves and camps off, every other hero kept dead unless the
stage brings one in, our hero in Red slot 0. The policy takes one decision
at its real spawn (policies remember home there), then the stage teleports
units into place. Each stage scores 0 to 100; a cell averages three classes
(Arcanist, Crossbowman, Berserker) by three seeds. The whole table for
thirteen columns runs in about a minute and is deterministic.

Build it like the replay extractors, in a polyworld worktree at the hosted
engine commit, with `POLYWORLD_DEPS` pointing at dependency symlinks whose
`bassy` matches that commit's `coworld/dependencies.lock`:

    mkdir -p tmp/diag && cp <andre_von_auto>/games/gods-of-the-arena/tools/gota_diag.nim tmp/diag/
    POLYWORLD_DEPS=<deps> nim c -d:headless -d:replayEvents \
      --path:examples/gods_of_the_arena -o:<dir>/gota_diag tmp/diag/gota_diag.nim
    cp examples/gods_of_the_arena/players/base.bas <dir>/

Run it with one `name=file.bas` per column; old versions come from git
(`git show <commit>:games/gods-of-the-arena/khors/khors.bas`):

    <dir>/gota_diag --seeds 3 v189=khors_v189.bas v180=khors_v180.bas base=base.bas

Columns appear in argument order, so list the newest version first. The
first row is the total (mean of the stages). `--html report.html` also
writes a standalone report in the Polyworld Buff site style (fonts and
icons hot linked from polyworld_art through media.githubusercontent.com, which
resolves its Git LFS files; jsDelivr serves the LFS pointers. Override with `--art URL`) with
green (75+), yellow (40-74) and red (under 40) cells; `--notes notes.txt`
adds one finding per line and `--build TEXT` sets the header badge.
`--tricks diag/tricks` adds a one-trick column: each row runs its own script
(`_helpers.bas` + `<Stage>.bas`) written only to pass that stage.
`--print` shows our hero's BASIC PRINT output, `--units` adds unit positions
to `--trace`.
`--stages GankEscape,SpellDodge` picks rows, `--classes Arcanist` narrows
the heroes, `--rows` prints every run to stderr, `--trace 24` prints hero
positions, health and targets once a second, `--geometry` dumps towers,
camps and lane points. Stage definitions and scoring are the doc comments on
each `stage*` proc. Results: ../diagnostics_2026-09-24.md.

## Structured API (2026-09-30)

khors v231 and everything after it use `' @gota-structures` records (`self`,
`objects(i)`, `abilities(slot)`, `items(slot)`, `match`, `map`, `draft`,
`players(i)`, `heroChoices(class)`). Cast ranges come live from
`abilities(slot).range`, so `gota_constants.nim` is only for legacy policies.
Positions are FIXED tile centers; `floor(p + .5)` gives the legacy whole tile,
with the Blue observer taking the lower cell on an exact tile edge (see
`mapTile` in khors.bas). `self.*` refreshes after every command, so read values
you need at decision start before issuing commands.
