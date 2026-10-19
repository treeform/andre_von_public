## Paintbot PW glory anatomy: for each replay, the winner's glory by award kind, so we can see
## what the ladder actually pays for. Works on hosted replay directories (needs the listing
## JSON for names) or pw_fast directories.
##
##   nim c -d:release -d:ssl -d:pwTraining --hints:off --warnings:off \
##     --path:$HOME/p/paintbot-pw-0124/examples/paintbot --path:$HOME/p/paintbot-pw-0124/src \
##     --path:tools -o:tools/pw_glory tools/pw_glory.nim
##   tools/pw_glory <dirs with replays>...
##
## Per side (even = Ember/red, odd = Azure/blue), means over the games that side won: final
## glory, seconds, base (600 minus seconds), and the awards by kind; then the same over all games.

import
  std/[os, strformat, strutils, tables],
  game, sim

type
  Tally = object
    games, wins: int
    glory, seconds: float
    awards: array[GloryKind, float]
    winGlory, winSeconds: float
    winAwards: array[GloryKind, float]

proc main() =
  var tallies: array[2, Tally]
  var count = 0
  for input in commandLineParams():
    for path in walkDirRec(input, yieldFilter = {pcFile, pcLinkToFile}):
      if not path.endsWith(".replay"):
        continue
      let recording = loadRecording(path)
      var
        w = newWorld(recording.seed, recording.endTick)
        awards: array[2, array[GloryKind, int]]
        seen = 0
      for frame in recording.frames:
        w.step(frame.commands, replayRulesVersion)
        # Events live GloryEventLifetime ticks; count each once by its tick order.
        for e in w.gloryEvents:
          if e.tick == w.tick:
            awards[e.team][e.kind] += e.amount
      inc count
      let scores = w.scores()
      for side in 0 .. 1:
        var t = addr tallies[side]
        inc t.games
        t.glory += scores[side]
        t.seconds += w.tick.float / TickRate.float
        for k in GloryKind:
          t.awards[k] += awards[side][k].float
        if scores[side] > scores[1 - side]:
          inc t.wins
          t.winGlory += scores[side]
          t.winSeconds += w.tick.float / TickRate.float
          for k in GloryKind:
            t.winAwards[k] += awards[side][k].float
  echo &"{count} replays"
  echo "| side | games | wins | win glory | seconds | base 600-s | quiet supplies | friendly fire | score hearts | behind lives | behind cogs |"
  echo "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|"
  for side in 0 .. 1:
    let
      t = tallies[side]
      n = max(t.wins, 1).float
      name = if side == 0: "even (red)" else: "odd (blue)"
    echo &"| {name} | {t.games} | {t.wins} | {t.winGlory / n:.0f} | {t.winSeconds / n:.0f} | {600 - t.winSeconds / n:.0f} | " &
      &"{t.winAwards[gloryQuietSupplies] / n:.0f} | {t.winAwards[gloryFriendlyFire] / n:.0f} | {t.winAwards[gloryHeart] / n:.0f} | " &
      &"{t.winAwards[gloryBehindLives] / n:.0f} | {t.winAwards[gloryBehindCogs] / n:.0f} |"

main()
