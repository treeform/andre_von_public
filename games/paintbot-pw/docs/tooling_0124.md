# Paintbot PW tooling on coworld-v0.3.124 (league "Paintbot")

Written 2026-10-08. Engine checkout: /Users/me/p/paintbot-pw-0124 (HEAD 7a29ed7, tag
coworld-v0.3.124). Previous engine: /Users/me/p/paintbot-pw-0110 (2f01fec, coworld-v0.3.110).
Neither breaking commit (28030de Bassy, 4d670ec rules 49) is in 0110. Nothing here was committed.

## League facts (coworld CLI `leagues league_ae677105... --json`, participation guide)

- League league_ae677105-0ab8-4561-81ec-c9cf6735821c "Paintbot", game game_867ef763-0642-4259-82b0-e1a8c68fff42,
  coworld cow_55019d36-0ec1-46ce-a51f-3545590624de (paintbot-pw), one division
  div_63c08219-c269-4bc5-84ae-5ccfc55b0a90 "Competition" (3 consecutive failures disqualify).
- Variant: commissioner_config.default_variant_id = "1v1", scheduler.variant_rotation = ["1v1"].
  Manifest variant "1v1" = 16 slots, team red on even and blue on odd slots, seed 2026,
  max_ticks 14400, glory behind_lives 5 and behind_cogs 10. So Seats = 16 and slot mod 2 in pw_xp stay right.
- Scheduler team_n, 2 teams interleaved, matchmaking elo_softmax (temperature 100), 12 episodes per round,
  rounds every 10 minutes, filler policy version c51834df-5ce1-4307-9134-b6e80211dece.
- Ladder openskill: mu 25, sigma 8.333, tau 0.4, margin_scale 600, new_version_sigma 6, round score mean.
- Dash JSON https://softmaxdash-nginx.tail0f4a29.ts.net/league/paintbot.json (138 KB, has allPolicies and
  ratings with champion, status and rank keys, which pw_xp.topThree reads).

## (1) pw_xp

- tools/pw_xp.nim constants: Dash = .../league/paintbot.json, Coworld = cow_55019d36-0ec1-46ce-a51f-3545590624de,
  Variant = "1v1". The source already carried the new coworld id (uncommitted edit of Oct 7, together with a
  `--coworld=` override flag) but the binary dated Oct 2 still embedded the old one. No league id is hard-coded in
  any tool (grep cow_ and league_ over tools/*.nim: only pw_xp). Variant "1v1" verified against the league.
- Rebuilt: `cd /Users/me/p/andre_von_auto/games/paintbot-pw && nim c -d:ssl --hints:off --warnings:off -o:tools/pw_xp tools/pw_xp.nim`
  (`strings tools/pw_xp | grep -o cow_...` now shows only cow_55019d36-0ec1-46ce-a51f-3545590624de).
- pw_fast.nim also has an older uncommitted edit (policy_ref support for our side). Left as found.

## (2) Replay extractors rebuilt against 0124

Build (run from /Users/me/p/andre_von_auto/games/paintbot-pw, one line per tool):

    nim c -d:release -d:ssl -d:pwTraining --hints:off --warnings:off \
      --path:/Users/me/p/paintbot-pw-0124/examples/paintbot --path:/Users/me/p/paintbot-pw-0124/src \
      --path:tools -o:tools/<name> tools/<name>.nim

for pw_stats, pw_fights, pw_timeline, pw_spots, pw_firstshot, pw_missanat (fastdirs.nim is a module they
import, it compiles but its binary is meaningless). Flags did not change. The engine's new dependencies bassy and
fixxy are found through /Users/me/p/nim.cfg (`--path:"bassy/src"`, `--path:"fixxy/src"` relative to /Users/me/p),
the engine's own config.nims is not read from our directory and is not needed. Caveat: nimby.lock pins bassy
77629c0, the local /Users/me/p/bassy is a02e6dd (lock + 3 commits: 907b69f record-support, b197584 borrowed blobs and
buffer limits, a02e6dd nn-tensors) plus a 10-line uncommitted change in src/bassy.nim and src/bassy/buffers.nim. The
engine's config.nims uses the same ../bassy/src, so engine tests and our tools agree. fixxy local = lock 05e5446.

Result: all seven compiled with no source change. No API break was hit: Command only gained `selfDestruct`,
PickupKind appended misterPickup, sniperPickup, radarPickup (array[PickupKind, int] grows by itself), Seats is
still the configureSeats template, MaxSeats 256, loadRecording converts rules 47 and older shapes.

Runtime check (re-simulation, no games): two rules-49 local replays (below) and one rules-48 hosted replay
(eps/replays/chart2_v50/ereq_00903fe7-08e6-4d89-9353-2e8644fa8cc6.replay) through all six tools: exit 0 everywhere,
"0 state-hash mismatches". The tools need a roster to label seats: a listing JSON next to the replays, or the
pw_fast directory shape eps/fast/<tag>/<rival>_vN_<side>_<seed>/games/NNN/replay.replay (fastdirs.nim); a plain
directory of replays is skipped ("replays without a roster skipped"). pw_timeline additionally needs
eps/fast/<tag>.tsv to split win and loss, without it it prints nothing (unchanged behaviour).

pw_stats edits for rules 49 (tools/pw_stats.nim): Seat.misterHeals (line 49), proc misted (lines 134-140),
copies of w.sniper, w.misterUntil, w.radarUntil per frame (lines 292-294), pickup detection (lines 389-402: a +1 HP
gain next to a living mister counts as "mister heals", anything else stays "medkits"; sniper, mister and radar pickups
from the seat arrays), rows "mister heals", "sniper rifles", "windex-misters", "radars" (Items section), and the
"deaths" description (one life from rules 49). Header build comment now names 0124. On the rules-48 replay the output
is identical to before except the four new rows at 0.00. On the smoke replay: sniper rifles 0.31/0.12, windex-misters
0.19/0.06, radars 0.12/0.12 per cog.

Cosmetic gaps left: pw_stats "lives left" is the lives counter plus one for a cog on the field, so a rules-49 survivor
reads 2.0 (dead 0.0); pw_fights "respawned lives" rows read "-" (no respawns) and its range buckets past 20 m are
sniper-only now (gun reach 2133 = 21.3 m); the header comments of pw_fights, pw_timeline, pw_spots, pw_firstshot,
pw_missanat and pw_fast still cite 0100 or 0110 paths; tools/readme.md still describes 0.3.79. pw_diag and pw_aim
were not rebuilt (not in scope; pw_diag's stages assume 3 HP and 3 lives and need a rules-49 review). pw_score and
pw_fetch do not link the engine.

Installed binaries: tools/pw_stats, pw_fights, pw_timeline, pw_spots, pw_firstshot, pw_missanat, pw_xp, plus new
tools/pw_headless and tools/pw_inspect. .gitignore gained tools/pw_firstshot, tools/pw_missanat, tools/pw_headless,
tools/pw_inspect (the first two binaries were untracked and unignored before).

## (3) Fast-XP servers (report only, nothing sent)

- https://fast-xp-request.tail0f4a29.ts.net and https://fast-xp-request-staging.tail0f4a29.ts.net: DNS resolves,
  TCP connect times out (20 s) on /v1/version, /health, / and /v1/metrics?minutes=15, curl code 000.
  `tailscale status`: fast-xp-request (100.106.82.37) offline, last seen 2 days ago; fast-xp-request-staging
  (100.77.89.20) offline, last seen 6 days ago. Engine version unknown, they accept nothing right now.
- https://fast-xp-k8s-staging.tail0f4a29.ts.net (100.94.136.73, active): /v1/games lists
  {"game":"paintbot-pw","current_version":"0.3.124","ready":true,"revision":"bb5d76f5..."} next to gota, awm, lvd,
  cta, so it runs the league engine (rules 49, Bassy). /v1/metrics?minutes=15 answers with a by_game array
  (paintbot-pw: 0 requests in the window, duration estimates full 56 s, gota busy with 803 games). /v1/version and
  /health return 404 {"error":"Not found"}. Whether it accepts a BASIC source roster was not tested (that is a hosted
  run, the orchestrator's job).
- tools/pw_fast.nim lists only the two dead hosts in Servers (line 24) and its load() reads top-level
  worker_limit, queued and running (lines 52-54) which the k8s server nests under by_game. Not changed.

## (4) One headless local game

Build (10 s, from the engine worktree; no -d:pwTraining, it silences the per-seat error echo, and no -d:coworld, it
reads COGAME_CONFIG_URI):

    cd /Users/me/p/paintbot-pw-0124 && nim c -d:headless --hints:off --warnings:off \
      --nimcache:/tmp/pw_headless_cache \
      -o:/Users/me/p/andre_von_auto/games/paintbot-pw/tools/pw_headless examples/paintbot/paintbot.nim
    nim c --hints:off --warnings:off -o:/Users/me/p/andre_von_auto/games/paintbot-pw/tools/pw_inspect \
      examples/paintbot/inspect_replay.nim

Run (`--bot` groups fill slots in order and team = slot mod 2, even Red and odd Blue, so alternate the two files
sixteen times; OURS on the even seats here):

    cd /Users/me/p/paintbot-pw-0124
    OURS=/Users/me/p/andre_von_auto/games/paintbot-pw/zhar/cand_v55.bas
    BASE=examples/paintbot/players/base.bas
    PW_BASIC_PEAKS=1 /Users/me/p/andre_von_auto/games/paintbot-pw/tools/pw_headless --seed 7 --ticks=1200 \
      --record /tmp/game.replay \
      --bot $OURS --bot $BASE --bot $OURS --bot $BASE --bot $OURS --bot $BASE --bot $OURS --bot $BASE \
      --bot $OURS --bot $BASE --bot $OURS --bot $BASE --bot $OURS --bot $BASE --bot $OURS --bot $BASE
    /Users/me/p/andre_von_auto/games/paintbot-pw/tools/pw_inspect /tmp/game.replay

Flags (src/polyworld/cli.nim and game.nim setup): `--seed N`, `--ticks=N` or `--seconds=N` or `--minutes=N`
(default 14400 ticks = 10 min, TickRate 24), `--record PATH`, `--map:<name>`, `--vision:team`, `--vision-range:N`,
`--glory:<json>`, `--mode:ffa_kin`. Errors: a BASIC compile error raises BasicError out of loadBots (bots.nim 198)
and kills the process with the message; a runtime BasicError prints `seat N disabled: <message>` (bots.nim 288), the
seat stands still for the rest of the match. The last line is `ticks=T captures=[red, blue] hash=H`;
PW_BASIC_PEAKS=1 adds per-seat peak_instructions and peak_work (budget 50,000 and 125,000 per decision). pw_inspect
prints walk moves and shot orders per seat and each cog's final position and hp. `nim r examples/paintbot/replay_stats.nim
PATH` gives per-team lives, captures and glory. For pw_stats and friends put the replay at
eps/fast/<tag>/<rival>_vN_<side>_<seed>/games/000/replay.replay.

Run 1, base.bas on both sides, seed 7, 1200 ticks: `ticks=1200 captures=[4, 3] hash=2717761225`, 3.9 s wall.
moves per seat [1200, 1200, 1200, 1200, 1035, 1200, 1200, 1200, 578, 1182, 1127, 1200, 1200, 1010, 939, 1200],
shots [8, 18, 17, 9, 3, 2, 6, 13, 11, 9, 11, 7, 13, 3, 2, 5], seats 4, 8, 10, 13, 14 dead at hp 0 (one life),
survivors at hp 2 to 10 (10 HP rules). Peaks 9,061 to 10,085 instructions and 14,958 to 16,636 work units.

Run 2, cand_v55.bas on Red (even) against base.bas, seed 7, 1200 ticks: exit 0, stdout

    seat 4 disabled: BASIC integer is outside the fixed-point range
    seat 6 disabled: BASIC integer is outside the fixed-point range
    seat 8 disabled: BASIC integer is outside the fixed-point range
    seat 12 disabled: BASIC integer is outside the fixed-point range
    seat 14 disabled: BASIC integer is outside the fixed-point range
    seat 10 disabled: BASIC integer is outside the fixed-point range
    seat 2 disabled: BASIC integer is outside the fixed-point range
    seat 0 disabled: BASIC value must be an exact int32
    ticks=1200 captures=[2, 5] hash=3277962042

Red seats moved 12, 7, 0, 0, 0, 6, 0, 0 ticks before freezing (peak instructions 3,371, 4,025, 3,460 for the three
that ran at all, 0 for the rest), Blue base seats moved 1192 to 1200. The script compiles (the legacy names selfX,
playerX, visible, worldTick are still provided next to me.* and agents(i), so the 139 legacy uses are not the
problem): `/` is fixed-point division now, so isqrt's `n / root` and every `/ 10`, `/ 2` and `/ 100` in cand_v55.bas
produce fractions that overflow the fixed-point range or reach walkTo as non-integers. The port needs `\` for every
integer division, TRUE = -1 and bitwise AND/OR/NOT review (docs/bassy-porting.md, guide.md "File policies").

## (5) auto_player

/Users/me/p/andre_von_auto/tools/auto_player.nim takes the league id as an argument: `submit <name:vN> <league id>`
(lines 163-171) runs `coworld submit <name:vN> -l <league id> --player <player id>` after verifying the version's
owner. Only player ids (Andre von Auto, Andre von Houck), the observatory SQL URL and the CLI path are hard-coded,
nothing about a league or a coworld. For the new league: `nim r -d:ssl tools/auto_player.nim submit zhar:vN
league_ae677105-0ab8-4561-81ec-c9cf6735821c` (and upload as before).

## Remaining breakage

- zhar/cand_v55.bas (champion zhar:v55, finist:v2) is unported and freezes on the first decision under Bassy.
- pw_fast points at two offline servers and parses the old metrics shape. fast-xp-k8s-staging runs 0.3.124.
- pw_diag and pw_aim not rebuilt or reviewed for rules 49.
- Stale build comments in five tool headers and tools/readme.md.
