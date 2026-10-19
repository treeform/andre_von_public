## Score a hosted experience request's episodes for one of our policies.
## Usage:
##   nim r tools/xp_score.nim <episodes.json> <policy> [versionA versionB]
##   nim r tools/xp_score.nim --team <baseline.json> <candidate.json> <policy>
## Single policy name: per-version mean/min/max over completed episodes.
## Two versions: paired per-episode diff (B - A), t stat, win share.
## --team: per-episode TEAM mean (all our seats) in each file, unpaired
## Welch t between the two files — the league-format 3-clone A/B. Either
## file argument may be a comma-separated list (west.json,east.json) to
## pool both-side arms.
## episodes.json comes from:
##   uv --project ~/p/metta run coworld xp-request episodes <xreq_id> --json

import std/[json, os, math, strformat, strutils, tables, algorithm, sequtils]

proc episodes(path: string): seq[JsonNode] =
  let d = parseJson(readFile(path))
  if d.kind == JArray: result = d.getElems()
  elif d.hasKey("entries"): result = d["entries"].getElems()
  else: result = d["episodes"].getElems()

proc scoreOf(ep: JsonNode, position: int): float =
  for s in ep["participant_scores"]:
    if s["position"].getInt() == position:
      return s["score"].getFloat()
  NaN

proc positionsOf(ep: JsonNode, policy: string): Table[int, int] =
  ## version -> position for our policy in this episode.
  for p in ep["participants"]:
    if p{"policy_name"}.getStr() == policy:
      result[p{"version"}.getInt()] = p["position"].getInt()

proc mean(xs: seq[float]): float =
  if xs.len == 0: return NaN
  var s = 0.0
  for x in xs: s += x
  s / xs.len.float

proc stdev(xs: seq[float]): float =
  if xs.len < 2: return 0.0
  let m = mean(xs)
  var s = 0.0
  for x in xs: s += (x - m) * (x - m)
  sqrt(s / (xs.len - 1).float)

proc teamMeans(paths, policy: string): seq[float] =
  ## `paths` may be comma-separated: both-side arms pool into one sample.
  for path in paths.split(','):
    for ep in episodes(path):
      if ep["status"].getStr() != "completed": continue
      var xs: seq[float]
      for p in ep["participants"]:
        if p{"policy_name"}.getStr() == policy:
          xs.add scoreOf(ep, p["position"].getInt())
      if xs.len > 0: result.add mean(xs)

proc welch(a, b: seq[float]): float =
  let sa = stdev(a)
  let sb = stdev(b)
  let se = sqrt(sa * sa / a.len.float + sb * sb / b.len.float)
  if se > 0: (mean(b) - mean(a)) / se else: 0.0

proc verdictLine(t, diff: float, wins, n: int): string =
  ## auto.md: at least 10 episodes before any keep.
  if n < 10: &"INCONCLUSIVE (only {n} episodes; need 10+)"
  elif t >= 2.0: "KEEP (significant)"
  elif diff <= 0 or t < 1.0: "REVERT"
  else: "INCONCLUSIVE (run more episodes)"

proc teamMode() =
  let
    policy = paramStr(4)
    base = teamMeans(paramStr(2), policy)
    cand = teamMeans(paramStr(3), policy)
    t = welch(base, cand)
  var wb, wc = 0
  for x in base:
    if x > 0.5: inc wb
  for x in cand:
    if x > 0.5: inc wc
  echo &"{policy} team A/B: baseline n={base.len} mean {mean(base):.3f} sd {stdev(base):.3f} W{wb}"
  echo &"                candidate n={cand.len} mean {mean(cand):.3f} sd {stdev(cand):.3f} W{wc}"
  echo &"  diff {mean(cand) - mean(base):+.3f}   Welch t = {t:.2f}"
  echo &"  verdict: {verdictLine(t, mean(cand) - mean(base), wc, cand.len)}"

proc pairedMode(policy: string, va, vb: int) =
  var a, b, diffs: seq[float]
  for ep in episodes(paramStr(1)):
    if ep["status"].getStr() != "completed": continue
    let pos = positionsOf(ep, policy)
    if pos.hasKey(va) and pos.hasKey(vb):
      let sa = scoreOf(ep, pos[va])
      let sb = scoreOf(ep, pos[vb])
      a.add sa
      b.add sb
      diffs.add sb - sa
  let n = diffs.len
  if n < 2:
    quit(&"only {n} paired episodes", 1)
  let
    md = mean(diffs)
    sd = stdev(diffs)
    t = if sd > 0: md / (sd / sqrt(n.float)) else: (if md > 0: Inf elif md < 0: -Inf else: 0.0)
  var wins, ties = 0
  for d in diffs:
    if d > 0: inc wins
    elif d == 0: inc ties
  echo &"{policy} v{va} -> v{vb}: paired n={n}"
  echo &"  mean v{va} {mean(a):.3f}   mean v{vb} {mean(b):.3f}   diff {md:+.3f} (sd {sd:.3f})"
  echo &"  t = {t:.2f}   v{vb} wins {wins} / ties {ties} / losses {n - wins - ties}"
  echo &"  verdict: {verdictLine(t, md, wins, n)}"

proc singleMode(policy: string) =
  var byVersion: Table[int, seq[float]]
  for ep in episodes(paramStr(1)):
    if ep["status"].getStr() != "completed": continue
    for v, pos in positionsOf(ep, policy):
      byVersion.mgetOrPut(v, @[]).add scoreOf(ep, pos)
  var versions = toSeq(byVersion.keys)
  versions.sort()
  for v in versions:
    let xs = byVersion[v]
    echo &"{policy} v{v}: n={xs.len} mean {mean(xs):.3f} sd {stdev(xs):.3f} min {xs.min:.3f} max {xs.max:.3f}"
    var line = "  scores:"
    for x in xs: line.add &" {x:.2f}"
    echo line

proc main() =
  if paramCount() >= 4 and paramStr(1) == "--team":
    teamMode()
  elif paramCount() >= 4:
    pairedMode(paramStr(2), parseInt(paramStr(3)), parseInt(paramStr(4)))
  elif paramCount() >= 2:
    singleMode(paramStr(2))
  else:
    quit("usage: xp_score <episodes.json> <policy> [vA vB] | --team <base.json> <cand.json> <policy>", 1)



## --field <files>: mean score per participant label across every completed
## episode, to see how each rival fares inside our own test games.
proc fieldMode() =
  if true:
    var sums = initTable[string, float]()
    var counts = initTable[string, int]()
    var positive = initTable[string, int]()
    for path in paramStr(2).split(','):
      for ep in episodes(path):
        if ep["status"].getStr() != "completed": continue
        for p in ep["participants"]:
          let label = p{"label"}.getStr()
          let s = scoreOf(ep, p["position"].getInt())
          if s.isNaN: continue
          sums[label] = sums.getOrDefault(label) + s
          counts[label] = counts.getOrDefault(label) + 1
          if s > 0: positive[label] = positive.getOrDefault(label) + 1
    var rows: seq[(float, string)]
    for label, total in sums:
      rows.add((total / counts[label].float, label))
    rows.sort(proc(a, b: (float, string)): int = cmp(b[0], a[0]))
    for (m, label) in rows:
      echo &"{label:<48} n {counts[label]:3} mean {m:6.0f} positive {positive.getOrDefault(label):3}"
    quit(0)

if paramCount() >= 2 and paramStr(1) == "--field":
  fieldMode()
else:
  main()
