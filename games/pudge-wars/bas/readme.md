# Pudge Wars BASIC bots (local self-play)

Polyworld BASIC (`.bas`) policies run inside the engine's VM: 20k
instructions per decision, integer math, globals persist across ticks
and start at 0, unknown variables read 0. The host API (self data,
objects, hooks, runes, actions) is documented in the header of
`sims/pudge-wars/examples/pudge_wars/players/base.bas`.

## Dependency layout

The engine's `config.nims` searches in-repo clones first (`vmath/src`,
`gltf/src`, `windy/src`, ...). Its `polyworld.nimble` also pulls the nimble
store, whose vmath 2.0.1 breaks the rendered client build, so symlink the
`~/p` checkouts into the engine dir once:

```bash
cd sims/pudge-wars && for d in vmath gltf windy silky shady noisy pixie chroma bumpy opengl flatty zippy fluffy nimsimd crunchy; do [ -e $d ] || ln -s ~/p/$d $d; done
```

With that in place both builds need no `--path` flags:

```bash
cd sims/pudge-wars && nim c -d:release -d:headless --hints:off --warnings:off -o:pwheadless examples/pudge_wars/pw.nim
cd sims/pudge-wars && nim c -d:release --hints:off --warnings:off -o:pw examples/pudge_wars/pw.nim
```

## Build the headless engine once

From the repo root:

```bash
cd sims/pudge-wars && nim c -d:release -d:headless --hints:off --warnings:off \
  --path:"$HOME/p/vmath/src" --path:"$HOME/p/flatty/src" --path:"$HOME/p/zippy/src" \
  --path:"$HOME/p/noisy/src" --path:"$HOME/p/fluffy/src" --path:"$HOME/p/silky/src" \
  --path:"$HOME/p/shady/src" --path:"$HOME/p/windy/src" --path:"$HOME/p/gltf/src" \
  -o:pwheadless examples/pudge_wars/pw.nim
```

A 10-minute duel simulates in about 1.3 s (~470x real time). Each match
writes `duels/match_*/{events.jsonl,summary.json,replay.pwr}` under the
engine directory; `duels/latest` points at the newest.

## Ladder

```bash
nim r --hints:off games/pudge-wars/bas/ladder.nim games/pudge-wars/bas/myasnik_vN.bas \
  sims/pudge-wars/examples/pudge_wars/players/base.bas [more refs] [--seeds 6] [--three]
```

Every seed runs twice (candidate west, then east). `--three` plays 3v3
clone teams, the league format. The engine's own `botlab.sh` does the
same for one reference.

## Versions

Engine checkout now 0a0140f (0.3.8 rules plus the shop protocol: public rune clock `runeSoon`/`runeNext*`, Lightning and Bounty runes, first to 30 in 20 minutes, hook range 60). CURRENT LOCAL BOT for this engine: `myasnik_v82.bas` = v75 + the rune clock (takes each drop the tick after it spawns, holds the chain through the drop, hooks a camper instead of a contested rune); 250-5-1 vs the new base and challenger on 64 seeds, runes 46-12 in a 20-minute game. Trees: see `stages/readme.md` — the script cannot see them, and the blind tree memory (v83) and cover search (v84) did not reduce catches over 16 seeds. Earlier: current bot on engine 395f3e4 (fog for scripts, 200-dmg hooks): `myasnik_v75.bas` = v21 + dodge at first sight (v40) + blind pokes aimed at the mirrored enemy pad (v48) + Distance upgrade first (v52) + the blind fallback alternating enemy pad and lane post each throw (v55) + brawl when dumped on the enemy bank (v60) + a point-blank chain before any melee, on either bank, when an enemy is within 20 tiles and the chain is ready (v61/v62) + the dodge committed for 28 ticks after the last threat tick, so our own sidestep no longer cancels it (v75). At 1024 games per bot (seeds 1-256, both banks, vs 2x challenger and 2x base): v75 7512W 111L 57D over 7680 games (seeds 1-2048; the 300-tick safe-opening variant v80 is 7541-94-45 on the same seeds, paired p ~0.1), v62 976W 33L 15D, v61 917W 81L 26D, v55 863W 127L 34D, v52 805W 156L 63D, v48 754-173-97, v40 (512 games) 304-135-73, v21 (512) 268-173-71. Loss rate per opponent went 39%/29% (v21) -> 31%/21% (v40) -> ~16%/14% (v48/v52) -> 13%/12% (v55) -> 9%/7% (v61) -> 4%/2% (v62) -> 1.4%/1.0% (v75). `myasnik_v35.bas` (rune-clock interception, on v21) is the pick when runes matter, e.g. against a human. Verdicts need `--seeds 128` (32-game samples swing by +-8 wins); with `--json` the runs are matched on seed+bank and `paired.nim A.json B.json` gives the McNemar test, which is the sharper call. On the older 2027b85 engine the best was `myasnik_v14.bas`; the two engines are different games.

One change per version; log idea, change, ladder result, verdict in
`../ideas.md`.

## Watching a match

Every logged match saves `replay.pwr`. The native client re-simulates it
with the 3D renderer (build once from `sims/pudge-wars` with
`nim c -d:release -o:pw examples/pudge_wars/pw.nim` plus the same
`--path` flags as the headless build):

```bash
cd sims/pudge-wars && ./pw --replay /path/to/match_*/replay.pwr
```

To log a 3v3 headless match for replay, add `--duellog DIR`.

## 2v2

The engine always seats six butchers, so a 2v2 pads each bank's third
seat with `idle.bas` (walks to its pad and never acts):

```bash
cd sims/pudge-wars && ./pwheadless \
  --bot "$PWD/../../games/pudge-wars/bas/myasnik_v3.bas:2" --bot "$PWD/../../games/pudge-wars/bas/idle.bas:1" \
  --bot "$PWD/examples/pudge_wars/players/challenger.bas:2" --bot "$PWD/../../games/pudge-wars/bas/idle.bas:1" \
  --seed 2 --killGoal 10 --minutes 10 --duellog /tmp/pw2v2
```

Drop `headless` (`./pw`, same flags, add `--speed 2`) to watch it live.

## Art pack for the rendered client

`./pw` loads assets from `../polyworld_data` (sibling of the engine dir):

```bash
cd sims && git clone --depth 1 https://github.com/Metta-AI/polyworld-data.git polyworld_data
ln -sfn main polyworld_data/themes/editor   # the viewer's UI theme; the public pack lacks "editor"
```

Missing HUD icons only become grey placeholders. Then:

```bash
cd sims/pudge-wars && ./pw --replay /tmp/pw2v2/match_*/replay.pwr --windowSize 1280x720 --speed 2
```

## True 2v2 (four butchers on the board)

Engine `395f3e4` (2026-09-03, "Break even-roster hook and rune lock-in")
ships official N-vs-N: `--team-size 2` seats four butchers. It also fixes
the bank bias we found (contested rune scoops go to the closest butcher
then RNG among sorted ids; equal-flight clashes snap both chains with no
deny gold; the hook cooldown is 65 ticks so throw cycles drift on every
roster). The older `--offseats` patch is obsolete; `bas/engine_offseats.patch`
stays only for the 2027b85 pin.

```bash
./pwheadless --team-size 2 --bot "$B/myasnik_v14.bas:2" \
  --bot "$PWD/examples/pudge_wars/players/challenger.bas:2" \
  --seed 2 --killGoal 10 --minutes 10 --duellog /tmp/pw2v2
./pw <same flags> --speed 2      # watch it live
```

## Analysis tools (duel logs from `ladder.nim --log DIR`)

- `nim r --hints:off games/pudge-wars/bas/analyze.nim <logroot>` — per-game rows and WIN/LOSS/DRAW means (kills by cause, death layer, accuracy by band, runes).
- `nim r --hints:off games/pudge-wars/bas/autopsy.nim <logroot>` — every death of ours reconstructed (layer, held, lip distance, partner distance, last enemy latch, damage by cause).
- `nim r --hints:off games/pudge-wars/bas/headshot_ops.nim <logroot>` — for every latch we make: reel ticks, partner distance and cooldown, whether a finisher throw was feasible.
- `nim r --hints:off games/pudge-wars/bas/throws.nim <sub> <logroot>` — throw and latch analytics: `denies` (our launches: denied / hit / miss), `misses` (closest enemy at our misses), `aim` (aim y vs enemy y at launch), `posts` (where enemies stand on their bank), `onus` (enemy latches on us by distance), `latchstate` (our state when a far poke lands), `allies` (partner latches: rescue vs crossfire), `returnleg` (return-leg catches), `farbank` (deaths after a dump).

Verdicts need `--seeds 128` (256 games per opponent); n=32 swings by +-8 wins.
