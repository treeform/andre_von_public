## Verdict tool for hosted top-3 experiments.
## Reads xp-request status JSON files (coworld xp-request get --json) for
## the champion and for one candidate, both run against the same frozen
## top-3 field, and reports per-policy seat means, within-episode pairwise
## win rates against the field seats, a two-proportion z-test on the pair
## win rates and a Welch t-test on seat scores (candidate vs champion).
## Scores come only from hosted episodes; nothing here runs a game.
##
##   nim r top3/verdict.nim <candidate> <champion.json>... -- <candidate.json>...

import
  std/[json, math, os, strutils, tables]

type
  Sample = object
    name: string
    seatScores: seq[float]
    pairWins: float      ## ties count half
    pairGames: int

proc normalCdf(z: float): float =
  0.5 * erfc(-z / sqrt(2.0))

proc studentTwoSidedP(t, df: float): float =
  ## Two-sided p for Student t via the regularized incomplete beta,
  ## evaluated with a continued fraction (Numerical Recipes betacf).
  proc betacf(a, b, x: float): float =
    const MaxIterations = 300
    const Epsilon = 3e-14
    var
      qab = a + b
      qap = a + 1.0
      qam = a - 1.0
      c = 1.0
      d = 1.0 - qab * x / qap
    if abs(d) < 1e-300: d = 1e-300
    d = 1.0 / d
    var h = d
    for m in 1 .. MaxIterations:
      let m2 = 2.0 * float(m)
      var aa = float(m) * (b - float(m)) * x / ((qam + m2) * (a + m2))
      d = 1.0 + aa * d
      if abs(d) < 1e-300: d = 1e-300
      c = 1.0 + aa / c
      if abs(c) < 1e-300: c = 1e-300
      d = 1.0 / d
      h *= d * c
      aa = -(a + float(m)) * (qab + float(m)) * x /
        ((a + m2) * (qap + m2))
      d = 1.0 + aa * d
      if abs(d) < 1e-300: d = 1e-300
      c = 1.0 + aa / c
      if abs(c) < 1e-300: c = 1e-300
      d = 1.0 / d
      let delta = d * c
      h *= delta
      if abs(delta - 1.0) < Epsilon:
        break
    h
  proc incompleteBeta(a, b, x: float): float =
    if x <= 0.0: return 0.0
    if x >= 1.0: return 1.0
    let front = exp(lgamma(a + b) - lgamma(a) - lgamma(b) +
      a * ln(x) + b * ln(1.0 - x))
    if x < (a + 1.0) / (a + b + 2.0):
      front * betacf(a, b, x) / a
    else:
      1.0 - front * betacf(b, a, 1.0 - x) / b
  let x = df / (df + t * t)
  incompleteBeta(df / 2.0, 0.5, x)

proc mean(values: seq[float]): float =
  if values.len == 0: return 0.0
  var total = 0.0
  for v in values: total += v
  total / float(values.len)

proc variance(values: seq[float]): float =
  if values.len < 2: return 0.0
  let m = mean(values)
  var total = 0.0
  for v in values: total += (v - m) * (v - m)
  total / float(values.len - 1)

proc collect(paths: seq[string], own: string,
             samples: var OrderedTable[string, Sample],
             episodes: var int) =
  ## Accumulates seat scores and pairwise records from completed episodes.
  for path in paths:
    let data = parseJson(readFile(path))
    for episode in data["episodes"]:
      if episode{"status"}.getStr() != "completed":
        continue
      inc episodes
      var seatScore = initTable[int, float]()
      for entry in episode["participant_scores"]:
        seatScore[entry["position"].getInt()] = entry["score"].getFloat()
      var seatLabel = initTable[int, string]()
      for participant in episode["participants"]:
        seatLabel[participant["position"].getInt()] =
          participant["label"].getStr()
      for seat, label in seatLabel:
        if not seatScore.hasKey(seat):
          continue
        if not samples.hasKey(label):
          samples[label] = Sample(name: label)
        samples[label].seatScores.add(seatScore[seat])
        let isOwn = label.startsWith(own & ":")
        for other, otherLabel in seatLabel:
          if other == seat or not seatScore.hasKey(other):
            continue
          let otherOwn = otherLabel.startsWith(own & ":")
          if isOwn == otherOwn:
            continue     # own vs own or field vs field: not scored
          if not isOwn:
            continue     # field seats are only scored from the own side
          inc samples[label].pairGames
          if seatScore[seat] > seatScore[other]:
            samples[label].pairWins += 1.0
          elif seatScore[seat] == seatScore[other]:
            samples[label].pairWins += 0.5

proc main() =
  let params = commandLineParams()
  let split = params.find("--")
  if params.len < 4 or split < 2 or split == params.len - 1:
    quit("usage: verdict <own-policy> <champion.json>... -- " &
      "<candidate.json>...", 1)
  let own = params[0]
  var champion = initOrderedTable[string, Sample]()
  var candidate = initOrderedTable[string, Sample]()
  var championEpisodes = 0
  var candidateEpisodes = 0
  collect(params[1 ..< split], own, champion, championEpisodes)
  collect(params[split + 1 .. ^1], own, candidate, candidateEpisodes)
  echo "champion episodes ", championEpisodes, ", candidate episodes ",
    candidateEpisodes
  echo "policy                      seats   mean    pairWR  pairGames"
  var championOwn, candidateOwn: Sample
  for table in [champion, candidate]:
    for label, sample in table:
      let isOwn = label.startsWith(own & ":")
      var rate = "   -  "
      if sample.pairGames > 0:
        rate = formatFloat(sample.pairWins / float(sample.pairGames),
          ffDecimal, 3)
      echo label.alignLeft(26), " ", ($sample.seatScores.len).align(5),
        "  ", formatFloat(mean(sample.seatScores), ffDecimal, 3).align(6),
        "  ", rate, "  ", sample.pairGames
      if isOwn:
        if table == champion: championOwn = sample
        else: candidateOwn = sample
  if championOwn.pairGames == 0 or candidateOwn.pairGames == 0:
    quit("own policy missing from one side", 1)
  # Two-proportion z-test on pairwise win rate (ties as half wins).
  let p1 = candidateOwn.pairWins / float(candidateOwn.pairGames)
  let p0 = championOwn.pairWins / float(championOwn.pairGames)
  let pooled = (candidateOwn.pairWins + championOwn.pairWins) /
    float(candidateOwn.pairGames + championOwn.pairGames)
  let se = sqrt(pooled * (1.0 - pooled) *
    (1.0 / float(candidateOwn.pairGames) +
     1.0 / float(championOwn.pairGames)))
  var z = 0.0
  if se > 0.0:
    z = (p1 - p0) / se
  let zp = 2.0 * (1.0 - normalCdf(abs(z)))
  echo ""
  echo "pairwise win rate vs field: candidate ",
    formatFloat(p1, ffDecimal, 3), " champion ",
    formatFloat(p0, ffDecimal, 3), "  z=", formatFloat(z, ffDecimal, 2),
    " p=", formatFloat(zp, ffScientific, 2)
  # Welch t-test on seat scores.
  let n1 = float(candidateOwn.seatScores.len)
  let n0 = float(championOwn.seatScores.len)
  let m1 = mean(candidateOwn.seatScores)
  let m0 = mean(championOwn.seatScores)
  let v1 = variance(candidateOwn.seatScores)
  let v0 = variance(championOwn.seatScores)
  let seT = sqrt(v1 / n1 + v0 / n0)
  var t = 0.0
  var df = 1.0
  if seT > 0.0:
    t = (m1 - m0) / seT
    df = (v1 / n1 + v0 / n0) * (v1 / n1 + v0 / n0) /
      ((v1 / n1) * (v1 / n1) / (n1 - 1.0) +
       (v0 / n0) * (v0 / n0) / (n0 - 1.0))
  let tp = studentTwoSidedP(t, df)
  echo "seat score: candidate ", formatFloat(m1, ffDecimal, 3),
    " (sd ", formatFloat(sqrt(v1), ffDecimal, 2), ") champion ",
    formatFloat(m0, ffDecimal, 3), " (sd ",
    formatFloat(sqrt(v0), ffDecimal, 2), ")  Welch t=",
    formatFloat(t, ffDecimal, 2), " df=", formatFloat(df, ffDecimal, 1),
    " p=", formatFloat(tp, ffScientific, 2)
  if p1 > p0 and zp < 0.01 and m1 > m0 and tp < 0.01:
    echo "verdict: candidate beats champion with significance (p < 0.01)"
  elif p1 <= p0 or m1 <= m0:
    echo "verdict: no improvement"
  else:
    echo "verdict: inconclusive, run more episodes"

main()
