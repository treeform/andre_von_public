# Paintbot PW tools

All Nim. The engine is the public checkout `~/p/paintbot-pw` (Metta-AI/paintbot-pw); keep it at the
commit of the league's coworld (0.3.79 = `d0728ab`, tag `coworld-v0.3.79`).

Build the two engine tools with the training telemetry on (it only adds counters):

    nim c -d:release -d:pwTraining --hints:off --warnings:off \
      --path:$HOME/p/paintbot-pw/examples/paintbot --path:$HOME/p/paintbot-pw/src \
      -o:tools/pw_stats tools/pw_stats.nim     # same flags for pw_diag

The other two need only `-d:ssl`: `nim c -d:ssl -o:tools/pw_xp tools/pw_xp.nim`.

- `pw_xp <tag> <policy:vN> [episodes]`: six hosted requests, our policy on the even and then the odd
  seats against each of the top three other players' live champions (from the dash JSON). Writes
  `eps/<tag>.txt`.
- `pw_score <tag> [<baseline tag>] [--replays]`: wins, draws, losses, Wilson interval, glory per
  episode and per win, per rival and pooled; with a baseline, win-rate z and glory Welch t.
  `--replays` downloads the episodes' replays to `eps/replays/<tag>/`. Keeps `eps/names.txt`
  (policy version id to label).
- `pw_stats [--diag diag.json] [--notes notes.md] [--md P] [--html P] <dirs>`: re-simulates every
  replay (state hash checked each tick) and prints one column per policy: league, survival, combat,
  items, movement, territory and order rows, plus the diagnostic rows from `pw_diag --json`. This is
  the combined report (docs/report_<date>.html).
- `pw_diag [--variants N] [--stages A,B] [--json P] [--md P] [--html P] name=policy.bas ...`: sixteen
  isolated skill stages in the real engine (aim, duels, outnumbered, team fight, grenade, medkit,
  armor, capture, defend, glory heart, friendly fire, full match vs base.bas), each 0 to 100.

League replays: `coworld replays -r <round> --json > eps/league/<round>.json` and
`coworld replays -r <round> -o eps/league/<round>`; they arrive gzipped, gunzip in place.
Unknown policy version ids: `coworld episodes <ereq> --json` lists participants with names.
