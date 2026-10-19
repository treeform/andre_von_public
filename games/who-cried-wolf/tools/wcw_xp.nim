## Who Cried Wolf hosted episode extractor.
##
##   nim r -d:ssl --hints:off games/who-cried-wolf/tools/wcw_xp.nim xreq_... [more ids]
##   nim r -d:ssl --hints:off games/who-cried-wolf/tools/wcw_xp.nim --policy name:vN [limit]
##
## Ids may be experience requests (xreq_) or episode requests (ereq_).
## `--policy` pulls the latest episodes that seated that policy version.
## Episode metadata comes from the coworld CLI, replays from public S3,
## both cached under games/who-cried-wolf/eps/cache. Prints one line per
## episode (setup, outcome, our seat), a per-label score table, and the
## vote table that feeds Volchok's vote model: for each voter faction, how
## often a ballot abstains, lands on a wolf, or lands on a packmate.
## `--compare <baseline xreqs> <candidate xreqs>` (comma-separated batches
## are pooled) runs a Welch t-test of our
## seat score stratified by the faction we were dealt (town 7/9, wolf 2/9),
## since the dealt role dominates the per-episode variance.

import
  std/[algorithm, json, math, os, strutils, tables],
  fetches

const
  Ours = "volchok"

var story = false

type
  Tally = object
    episodes: int
    total: float
    wins: int
    read: float
    reads: int

  KillTally = object
    candidates: int
    expected: float
    victims: int

  VoteTally = object
    ballots: int
    abstains: int
    onWolf: int
    onPackmate: int
    chance: float

proc betaFraction(a, b, x: float): float =
  ## Continued fraction for the regularized incomplete beta function.
  var
    c = 1.0
    d = 1.0 - (a + b) * x / (a + 1)
  if abs(d) < 1e-300:
    d = 1e-300
  d = 1 / d
  result = d
  for m in 1 .. 300:
    let
      mf = m.float
      even = mf * (b - mf) * x / ((a + 2 * mf - 1) * (a + 2 * mf))
    d = 1 + even * d
    c = 1 + even / c
    d = 1 / (if abs(d) < 1e-300: 1e-300 else: d)
    result *= d * (if abs(c) < 1e-300: 1e300 else: c)
    let odd = -(a + mf) * (a + b + mf) * x /
      ((a + 2 * mf) * (a + 2 * mf + 1))
    d = 1 + odd * d
    c = 1 + odd / c
    d = 1 / (if abs(d) < 1e-300: 1e-300 else: d)
    let step = d * (if abs(c) < 1e-300: 1e300 else: c)
    result *= step
    if abs(step - 1) < 1e-12:
      break

proc twoSidedP(t, df: float): float =
  ## Returns the two-sided Student t p-value.
  let x = df / (df + t * t)
  let (a, b) = (df / 2, 0.5)
  let front = exp(lgamma(a + b) - lgamma(a) - lgamma(b) +
    a * ln(x) + b * ln(1 - x))
  if x < (a + 1) / (a + b + 2):
    front * betaFraction(a, b, x) / a
  else:
    1 - front * betaFraction(b, a, 1 - x) / b

proc ourScores(ids: seq[string]): Table[string, seq[float]] =
  ## Returns our seat's score per episode, grouped by our faction, plus
  ## our town read in games where we lived past night 1 ("survivor read"),
  ## also split by how many wolves cast any ballot ("survivor read wN"),
  ## which is the wolves' behaviour and caps what any ballot reader learns.
  for id in ids:
    let meta = episode(id)
    let url = meta{"replay_url"}.getStr()
    if url.len == 0:
      continue
    let
      data = replay(id, url)
      table = seats(meta, data)
    var voted: array[9, bool]
    for event in data{"events"}:
      let payload = event{"payload"}
      if payload{"kind"}.getStr() == "ballots":
        for ballot in payload{"ballots"}:
          if ballot{"target"}.kind == JInt:
            voted[ballot{"slot"}.getInt()] = true
    var votingWolves = 0
    for slot in 0 ..< 9:
      if table[slot].faction == "wolf" and voted[slot] and
        not table[slot].label.startsWith(Ours):
          inc votingWolves
    for seat in table:
      if seat.label.startsWith(Ours):
        result.mgetOrPut(seat.faction, @[]).add seat.score
        if seat.faction == "town" and
          seat.metrics{"survived"}.getFloat() > 0:
            let read = seat.metrics{"read"}.getFloat()
            result.mgetOrPut("survivor read", @[]).add read
            result.mgetOrPut("survivor read w" & $votingWolves, @[]).add read

proc moments(xs: seq[float]): (float, float) =
  ## Returns the mean and sample variance.
  var mean = 0.0
  for x in xs:
    mean += x
  mean /= max(1, xs.len).float
  var variance = 0.0
  for x in xs:
    variance += (x - mean) * (x - mean)
  (mean, variance / max(1, xs.len - 1).float)

proc welchLine(name: string, xs, ys: seq[float]) =
  ## Prints a Welch t-test of candidate minus baseline for one metric.
  if xs.len == 0 and ys.len == 0:
    return
  let
    (meanA, varA) = moments(xs)
    (meanB, varB) = moments(ys)
  var line = name.alignLeft(18) & " base " & formatFloat(meanA, ffDecimal, 4) &
    " (n " & $xs.len & ") cand " & formatFloat(meanB, ffDecimal, 4) &
    " (n " & $ys.len & ")"
  let
    partA = varA / max(1, xs.len).float
    partB = varB / max(1, ys.len).float
  if xs.len >= 2 and ys.len >= 2 and partA + partB > 0:
    let
      t = (meanB - meanA) / sqrt(partA + partB)
      df = (partA + partB) * (partA + partB) /
        (partA * partA / (xs.len - 1).float +
        partB * partB / (ys.len - 1).float)
    line.add " t " & formatFloat(t, ffDecimal, 2) & " df " &
      formatFloat(df, ffDecimal, 1) & " p " &
      formatFloat(twoSidedP(t, df), ffDecimal, 4)
  echo line

proc compare(baseline, candidate: string) =
  ## Faction-stratified Welch test of our score, candidate minus baseline.
  const Weights = [("town", 7.0 / 9.0), ("wolf", 2.0 / 9.0)]
  let
    a = ourScores(episodeIds(baseline.split(",")))
    b = ourScores(episodeIds(candidate.split(",")))
  var diff, variance, dfDenominator = 0.0
  echo "faction  base n  mean    cand n  mean    diff"
  for (faction, weight) in Weights:
    let
      xs = a.getOrDefault(faction)
      ys = b.getOrDefault(faction)
      (meanA, varA) = moments(xs)
      (meanB, varB) = moments(ys)
    echo faction.alignLeft(8), " ", ($xs.len).align(6), " ",
      formatFloat(meanA, ffDecimal, 4), " ", ($ys.len).align(7), " ",
      formatFloat(meanB, ffDecimal, 4), " ",
      formatFloat(meanB - meanA, ffDecimal, 4)
    if xs.len < 2 or ys.len < 2:
      continue
    diff += weight * (meanB - meanA)
    let
      partA = weight * weight * varA / xs.len.float
      partB = weight * weight * varB / ys.len.float
    variance += partA + partB
    dfDenominator += partA * partA / (xs.len - 1).float +
      partB * partB / (ys.len - 1).float
  if variance <= 0:
    echo "stratified diff ", formatFloat(diff, ffDecimal, 4), ", no variance"
    return
  let
    t = diff / sqrt(variance)
    df = variance * variance / dfDenominator
  echo "stratified diff ", formatFloat(diff, ffDecimal, 4), " t ",
    formatFloat(t, ffDecimal, 2), " df ", formatFloat(df, ffDecimal, 1),
    " p ", formatFloat(twoSidedP(t, df), ffDecimal, 4)
  for key in ["survivor read", "survivor read w0", "survivor read w1",
    "survivor read w2"]:
      welchLine(key, a.getOrDefault(key), b.getOrDefault(key))

proc main() =
  ## Prints episode lines, the label table, and the vote table.
  if paramCount() < 1:
    quit("usage: wcw_xp <xreq_|ereq_ ids> | --policy name:vN [limit] | " &
      "--compare <baseline xreq> <candidate xreq>", 2)
  createDir(CacheDir)
  story = "--story" in commandLineParams()
  if paramStr(1) == "--compare":
    compare(paramStr(2), paramStr(3))
    return
  var
    labels = initTable[string, Tally]()
    votes = initTable[string, VoteTally]()
    kills: array[3, KillTally]
  for id in episodeIds(commandLineParams()):
    let meta = episode(id)
    let url = meta{"replay_url"}.getStr()
    if url.len == 0:
      continue
    let
      data = replay(id, url)
      table = seats(meta, data)
      outcome = data{"result"}
    var line = id[0 ..< 13] & " " & outcome{"outcome"}.getStr() &
      " d" & $outcome{"daysCompleted"}.getInt()
    for slot, seat in table:
      var tally = labels.getOrDefault(seat.label)
      inc tally.episodes
      tally.total += seat.score
      tally.wins += seat.metrics{"win"}.getInt()
      if seat.metrics.hasKey("read"):
        tally.read += seat.metrics{"read"}.getFloat()
        inc tally.reads
      labels[seat.label] = tally
      if seat.label.startsWith(Ours):
        line.add "  " & seat.label & "@" & $slot & " " & seat.role &
          " score " & $seat.score & " " & $seat.metrics
    echo line
    if story:
      var lineup = ""
      for slot, seat in table:
        lineup.add "  " & $slot & "=" & seat.label.split(":")[0] & "/" & seat.role
      echo "   ", lineup
      for event in data{"events"}:
        let payload = event{"payload"}
        case payload{"kind"}.getStr()
        of "ballots":
          var counts = initCountTable[int]()
          var row = ""
          for ballot in payload{"ballots"}:
            let target = ballot{"target"}
            row.add (if target.kind == JNull: "-" else: $target.getInt())
            if target.kind == JInt:
              counts.inc target.getInt()
          echo "   d", event{"day"}.getInt(), " votes [", row, "] ",
            payload{"resolution"}.getStr(), " out ",
            (if payload{"eliminated"}.kind == JInt:
              $payload{"eliminated"}.getInt() & "/" &
                table[payload{"eliminated"}.getInt()].role
            else: "-")
        of "elimination":
          if payload{"cause"}.getStr() == "wolf":
            echo "   n", event{"day"}.getInt(), " killed ",
              payload{"slot"}.getInt(), "/", payload{"role"}.getStr()
        else:
          discard
    var
      alive: array[9, bool]
      today: array[9, int]
    for slot in 0 ..< 9:
      alive[slot] = true
      today[slot] = 2
    for event in data{"events"}:
      let payload = event{"payload"}
      case payload{"kind"}.getStr()
      of "ballots":
        for slot in 0 ..< 9:
          today[slot] = 2
        for ballot in payload{"ballots"}:
          let target = ballot{"target"}
          today[ballot{"slot"}.getInt()] =
            if target.kind == JNull: 2
            elif table[target.getInt()].faction == "wolf": 0
            else: 1
        var living, wolves = 0
        for ballot in payload{"ballots"}:
          inc living
          if table[ballot{"slot"}.getInt()].faction == "wolf":
            inc wolves
        for ballot in payload{"ballots"}:
          let
            voter = ballot{"slot"}.getInt()
            target = ballot{"target"}
            key = table[voter].faction & " " &
              table[voter].label.split(":")[0]
          var tally = votes.getOrDefault(key)
          inc tally.ballots
          if target.kind == JNull:
            inc tally.abstains
          else:
            let hit = table[target.getInt()].faction == "wolf"
            if hit:
              inc tally.onWolf
              if table[voter].faction == "wolf":
                inc tally.onPackmate
            let ownWolf = int(table[voter].faction == "wolf")
            tally.chance += (wolves - ownWolf).float / (living - 1).float
          votes[key] = tally
      of "elimination":
        let victim = payload{"slot"}.getInt()
        if payload{"cause"}.getStr() == "wolf":
          var pool: seq[int]
          for slot in 0 ..< 9:
            if alive[slot] and table[slot].faction != "wolf":
              pool.add slot
          for slot in pool:
            inc kills[today[slot]].candidates
            kills[today[slot]].expected += 1 / pool.len
          inc kills[today[victim]].victims
        alive[victim] = false
      else:
        discard
  echo ""
  echo "label                              eps   mean   wins  read"
  var names: seq[string]
  for name in labels.keys:
    names.add name
  names.sort()
  for name in names:
    let tally = labels[name]
    echo name.alignLeft(32), " ", ($tally.episodes).align(4), " ",
      formatFloat(tally.total / tally.episodes.float, ffDecimal, 3).align(6),
      " ", ($tally.wins).align(5), " ",
      (if tally.reads > 0:
        formatFloat(tally.read / tally.reads.float, ffDecimal, 3)
      else: "-").align(5)
  echo ""
  echo "voter (faction policy)             ballots abstain onWolf chance pack"
  names.setLen(0)
  for name in votes.keys:
    names.add name
  names.sort()
  for name in names:
    let tally = votes[name]
    echo name.alignLeft(32), " ", ($tally.ballots).align(7), " ",
      ($tally.abstains).align(7), " ", ($tally.onWolf).align(6), " ",
      formatFloat(tally.chance, ffDecimal, 1).align(6), " ",
      ($tally.onPackmate).align(4)
  echo ""
  echo "night kill victim by that day's ballot  candidates expected victims"
  for i, name in ["voted a wolf", "voted town", "abstained"]:
    echo name.alignLeft(38), " ", ($kills[i].candidates).align(10), " ",
      formatFloat(kills[i].expected, ffDecimal, 1).align(8), " ",
      ($kills[i].victims).align(7)

main()
