## Score Paintbot Season 2 hosted experience requests by Glory.
##
## Glory is exponential (a product of deed multipliers), so every test runs
## on log2(1 + score) and a rank test, never on raw means.
##
##   nim r tools/glory_score.nim <policy> <episodes.json>
##   nim r tools/glory_score.nim <basePolicy> <baseline.json> <candPolicy> <candidate.json>
## --only=ID,ID,... restricts the CANDIDATE and baseline files to those episode ids
## (prefixes), for "count only games where the change fired".
## Either file argument may be a comma-joined list (a.json,b.json) to pool arms.
##
## episodes.json comes from:
##   uvx --from ~/p/metta-coworld-cli/packages/coworld[auth] coworld xp-request episodes <xreq_id> --json
## One file: per-episode score, rank of 16, top score, then a summary. Two
## files: candidate vs baseline for the policy (any version) — Welch t on
## the log scores, Mann-Whitney U with a normal approximation, rank-1 rate —
## and a verdict: KEEP needs t >= 2 and p < 0.05 in the candidate's favour.

import std/[algorithm, json, math, os, sequtils, strformat, strutils, tables]

type Episode = object
  id: string
  score: float
  rank: int
  seats: int
  top: float

proc episodes(path: string): seq[JsonNode] =
  let d = parseJson(readFile(path))
  if d.kind == JArray: d.getElems()
  elif d.hasKey("entries"): d["entries"].getElems()
  else: d["episodes"].getElems()

var onlyIds: seq[string]  ## --only ID,ID,... keeps listed episode ids (prefix match)

proc ours(paths, policy: string): seq[Episode] =
  ## `paths` may be a comma-joined list: arms spread over several requests.
  ## Scores are matched by policy_version_id (the `scores` array is NOT in
  ## slot order); position is only a fallback for score rows without an id.
  var pooled: seq[JsonNode]
  for path in paths.split(','):
    pooled.add episodes(path.strip)
  for ep in pooled:
    if ep{"status"}.getStr != "completed": continue
    if onlyIds.len > 0:
      var keep = false
      for id in onlyIds:
        if ep{"id"}.getStr.startsWith(id): keep = true
      if not keep: continue
    let scores = ep{"scores"}
    if scores == nil or scores.kind != JArray: continue
    var values: seq[float]
    var byVersion = initTable[string, seq[float]]()
    for s in scores:
      let v = if s.kind == JObject: s{"score"}.getFloat else: s.getFloat
      values.add v
      if s.kind == JObject:
        byVersion.mgetOrPut(s{"policy_version_id"}.getStr, @[]).add v
    for p in ep{"participants"}:
      if p{"policy_name"}.getStr != policy: continue
      let id = p{"policy_version_id"}.getStr
      var v: float
      if byVersion.hasKey(id) and byVersion[id].len > 0:
        v = byVersion[id][0]
        byVersion[id].delete(0)
      else:
        let position = p{"position"}.getInt
        if position >= values.len: continue
        v = values[position]
      var rank = 1
      for other in values:
        if other > v: inc rank
      result.add Episode(id: ep{"id"}.getStr, score: v, rank: rank,
                         seats: values.len, top: max(values))

proc logScore(e: Episode): float = log2(1.0 + max(e.score, 0.0))

proc mean(xs: seq[float]): float =
  if xs.len == 0: NaN else: xs.foldl(a + b) / xs.len.float

proc variance(xs: seq[float]): float =
  if xs.len < 2: return NaN
  let m = mean(xs)
  xs.mapIt((it - m) * (it - m)).foldl(a + b) / (xs.len - 1).float

proc median(xs: seq[float]): float =
  if xs.len == 0: return NaN
  let s = xs.sorted
  if s.len mod 2 == 1: s[s.len div 2] else: (s[s.len div 2 - 1] + s[s.len div 2]) / 2

proc welch(a, b: seq[float]): float =
  ## t for b - a.
  let se = sqrt(variance(a) / a.len.float + variance(b) / b.len.float)
  if se == 0 or se.isNaN: 0.0 else: (mean(b) - mean(a)) / se

proc normalCdf(z: float): float = 0.5 * (1.0 + erf(z / sqrt(2.0)))

proc mannWhitney(a, b: seq[float]): (float, float) =
  ## U for b over a, and the two-sided normal-approximation p (ties averaged).
  var all: seq[(float, int)]
  for x in a: all.add (x, 0)
  for x in b: all.add (x, 1)
  all.sort(proc(p, q: (float, int)): int = cmp(p[0], q[0]))
  var ranks = newSeq[float](all.len)
  var i = 0
  while i < all.len:
    var j = i
    while j + 1 < all.len and all[j + 1][0] == all[i][0]: inc j
    let r = (i + j).float / 2 + 1
    for k in i .. j: ranks[k] = r
    i = j + 1
  var rb = 0.0
  for k, item in all:
    if item[1] == 1: rb += ranks[k]
  let n1 = a.len.float
  let n2 = b.len.float
  let u = rb - n2 * (n2 + 1) / 2
  let mu = n1 * n2 / 2
  let sigma = sqrt(n1 * n2 * (n1 + n2 + 1) / 12)
  if sigma == 0: return (u, 1.0)
  let z = (u - mu) / sigma
  (u, 2 * (1 - normalCdf(abs(z))))

proc summary(label: string, eps: seq[Episode]) =
  let logs = eps.mapIt(logScore(it))
  let wins = eps.countIt(it.rank == 1)
  echo &"{label}: n {eps.len}  sum {eps.mapIt(it.score).foldl(a + b):.0f}  median {median(eps.mapIt(it.score)):.0f}  " &
       &"mean log2 {mean(logs):.2f}  mean rank {mean(eps.mapIt(it.rank.float)):.1f}  wins {wins}"

proc main() =
  var args: seq[string]
  for i in 1 .. paramCount():
    let a = paramStr(i)
    if a.startsWith("--only="): onlyIds = a[7 .. ^1].split(',')
    else: args.add a
  if args.len != 2 and args.len != 4:
    quit("usage: glory_score <policy> <episodes.json> | <basePolicy> <base.json> <candPolicy> <cand.json>", 2)
  let policy = args[0]
  let base = ours(args[1], policy)
  if base.len == 0: quit("no completed episodes for " & policy & " in " & args[1], 1)
  if args.len == 2:
    for e in base:
      echo &"  {e.id[0 ..< min(13, e.id.len)]}  score {e.score:.0f}  rank {e.rank} of {e.seats}  top {e.top:.0f}"
    summary("ours", base)
    return
  let candPolicy = args[2]
  let cand = ours(args[3], candPolicy)
  if cand.len == 0: quit("no completed episodes for " & candPolicy & " in " & args[3], 1)
  summary("baseline ", base)
  summary("candidate", cand)
  let la = base.mapIt(logScore(it))
  let lb = cand.mapIt(logScore(it))
  let t = welch(la, lb)
  let (u, p) = mannWhitney(la, lb)
  let favours = mean(lb) > mean(la)
  let winA = base.countIt(it.rank == 1).float / base.len.float
  let winB = cand.countIt(it.rank == 1).float / cand.len.float
  let winsA = base.countIt(it.rank == 1)
  let winsB = cand.countIt(it.rank == 1)
  let pooled = (winsA + winsB).float / (base.len + cand.len).float
  let seWins = sqrt(pooled * (1 - pooled) * (1 / base.len.float + 1 / cand.len.float))
  let zWins = if seWins == 0: 0.0 else: (winB - winA) / seWins
  let pWins = 2 * (1 - normalCdf(abs(zWins)))
  echo &"log2 Welch t {t:.2f}  Mann-Whitney U {u:.0f} p {p:.3f}  win rate {winA:.2f} -> {winB:.2f}  wins {winsA}/{base.len} -> {winsB}/{cand.len}  two-proportion z {zWins:.2f} p {pWins:.3f}"
  if t >= 2.0 and p < 0.05 and favours:
    echo "verdict: KEEP"
  elif t <= -2.0:
    echo "verdict: REVERT"
  else:
    let d = abs(mean(lb) - mean(la))
    let pooled = (variance(la) + variance(lb)) / 2
    let need = if d == 0: 0 else: int(ceil(8.0 * pooled / (d * d)))
    echo &"verdict: INCONCLUSIVE (about {need} episodes per arm for t=2 at this effect)"

main()
