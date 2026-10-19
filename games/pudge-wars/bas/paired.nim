## Paired comparison of two ladder runs (ladder.nim --json). The sim is
## deterministic per seed, so the same seed and bank against the same
## reference is a matched pair: only discordant pairs carry evidence.
## Reports, per reference and pooled: A's and B's records, the number of
## pairs where A did strictly better / worse (win > draw > loss), and the
## exact two-sided binomial p-value on those discordant pairs (McNemar).
##
##   nim r --hints:off games/pudge-wars/bas/paired.nim A.json B.json

import std/[os, json, strutils, strformat, tables, math]

proc rank(r: string): int =
  case r
  of "win": 2
  of "draw": 1
  of "loss": 0
  else: -1

proc binomTwoSided(k, n: int): float =
  ## Exact two-sided p-value for k successes of n at p = 0.5.
  if n == 0: return 1.0
  var probs: seq[float]
  for i in 0 .. n:
    var lc = 0.0
    for j in 1 .. i: lc += ln(float(n - i + j)) - ln(float(j))
    probs.add exp(lc - float(n) * ln(2.0))
  let pk = probs[k]
  var p = 0.0
  for q in probs:
    if q <= pk + 1e-12: p += q
  min(1.0, p)

proc records(games: JsonNode): (int, int, int) =
  var w, l, d: int
  for g in games:
    case g{"result"}.getStr
    of "win": inc w
    of "loss": inc l
    of "draw": inc d
    else: discard
  (w, l, d)

proc main() =
  if paramCount() < 2:
    quit("usage: paired A.json B.json", 2)
  let a = parseJson(readFile(paramStr(1)))
  let b = parseJson(readFile(paramStr(2)))
  let nameA = a{"candidate"}.getStr.extractFilename
  let nameB = b{"candidate"}.getStr.extractFilename
  var refsB = initTable[string, JsonNode]()
  for r in b{"perReference"}: refsB[r{"reference"}.getStr] = r
  var totBetter, totWorse, totPairs = 0
  for ra in a{"perReference"}:
    let key = ra{"reference"}.getStr
    if key notin refsB: continue
    let rb = refsB[key]
    var byKey = initTable[string, string]()
    for g in rb{"games"}:
      byKey[$g{"seed"}.getInt & (if g{"candWest"}.getBool: "w" else: "e")] = g{"result"}.getStr
    var better, worse, pairs = 0
    for g in ra{"games"}:
      let k = $g{"seed"}.getInt & (if g{"candWest"}.getBool: "w" else: "e")
      if k notin byKey: continue
      let x = rank(g{"result"}.getStr)
      let y = rank(byKey[k])
      if x < 0 or y < 0: continue
      inc pairs
      if x > y: inc better
      elif x < y: inc worse
    let (wa, la, da) = records(ra{"games"})
    let (wb, lb, db) = records(rb{"games"})
    echo &"{key.extractFilename}: {nameA} {wa}W {la}L {da}D vs {nameB} {wb}W {lb}L {db}D | pairs {pairs}, {nameA} better in {better}, worse in {worse}, p = {binomTwoSided(better, better + worse):.3f}"
    totBetter += better; totWorse += worse; totPairs += pairs
  echo &"POOLED: pairs {totPairs}, {nameA} better in {totBetter}, worse in {totWorse}, p = {binomTwoSided(totBetter, totBetter + totWorse):.3f}"

main()
