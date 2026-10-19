## Paintbot PW head-to-head: our policy against each rival over any number of hosted XP
## tags, with significance on the win rate (binomial z against 50%) and on the score
## (paired t on our glory minus theirs, episode by episode).
##
##   nim c -d:release -d:ssl --hints:off --warnings:off -o:tools/pw_h2h tools/pw_h2h.nim
##   tools/pw_h2h <tag>... [--html path] [--md path]
##
## Every tag is an eps/<tag>.txt written by pw_xp (one line per request: id, side, rival).
## Only completed episodes count. Draws (both scores 0) are listed and left out of the
## win-rate test.

import
  std/[json, math, os, osproc, sequtils, strformat, strutils, tables]

type
  Episode = object
    rival, side: string
    ours, theirs: float
  Row = object
    rival: string
    n, w, d, l: int
    ours, theirs: seq[float]

proc cli(): string =
  ## Returns the coworld CLI command backed by the stable metta checkout.
  "uvx --from " & quoteShell(getHomeDir() / "p/metta-coworld-cli/packages/coworld[auth]") &
    " coworld"

proc request(id: string): JsonNode =
  ## Returns one request's JSON, from the cache once it has completed.
  let path = "eps/xp" / id & ".json"
  if fileExists(path):
    return parseJson(readFile(path))
  let (output, code) = execCmdEx(
    cli() & " xp-request get " & id & " --json",
    options = {poUsePath, poEvalCommand}
  )
  let start = output.find('{')
  if code != 0 or start < 0:
    quit("pw_h2h: xp-request get failed for " & id & "\n" & output, 1)
  result = parseJson(output[start .. ^1])
  if result["status"].getStr in ["completed", "failed"]:
    createDir("eps/xp")
    writeFile(path, $result)

proc loadFast(tag: string): seq[Episode] =
  ## Loads a pw_fast tag (eps/fast/<tag>.tsv: rival, side, seed, ours, theirs, ticks, seconds).
  for line in lines("eps/fast" / tag & ".tsv"):
    let f = line.split('\t')
    if f.len < 5:
      continue
    result.add Episode(rival: f[0], side: f[1], ours: parseFloat(f[3]), theirs: parseFloat(f[4]))

proc load(tag: string): seq[Episode] =
  ## Loads every completed episode listed under one tag.
  for line in lines("eps" / tag & ".txt"):
    let parts = line.splitWhitespace
    if parts.len < 3:
      continue
    let
      data = request(parts[0])
      ourParity =
        if parts[1] == "red":
          0
        else:
          1
    for e in data["episodes"]:
      if e["status"].getStr != "completed":
        continue
      var
        ours = NaN
        theirs = NaN
      for s in e["participant_scores"]:
        if s["position"].getInt mod 2 == ourParity:
          ours = s["score"].getFloat
        else:
          theirs = s["score"].getFloat
      if ours.isNaN or theirs.isNaN:
        continue
      result.add Episode(rival: parts[2], side: parts[1], ours: ours, theirs: theirs)

proc mean(values: seq[float]): float =
  ## Returns the arithmetic mean, 0 for no values.
  if values.len == 0:
    return 0
  values.sum / values.len.float

proc variance(values: seq[float]): float =
  ## Returns the sample variance.
  if values.len < 2:
    return 0
  let m = mean(values)
  values.mapIt((it - m) * (it - m)).sum / float(values.len - 1)

proc wilson(k, n: int): (float, float) =
  ## Returns the 95% Wilson interval of k successes in n.
  if n == 0:
    return (0.0, 1.0)
  let
    z = 1.96
    p = k / n
    d = 1 + z * z / n.float
    c = (p + z * z / (2 * n.float)) / d
    h = z * sqrt(p * (1 - p) / n.float + z * z / (4 * n.float * n.float)) / d
  (c - h, c + h)

proc twoSided(z: float): float =
  ## Two-sided normal p-value of a z score.
  erfc(abs(z) / sqrt(2.0))

proc add(row: var Row, e: Episode) =
  ## Adds one episode to a row.
  inc row.n
  if e.ours > e.theirs:
    inc row.w
  elif e.theirs > e.ours:
    inc row.l
  else:
    inc row.d
  row.ours.add e.ours
  row.theirs.add e.theirs

proc stats(row: Row): (float, float, float, float, float, float, float, float) =
  ## Returns win %, Wilson low, Wilson high, win z, win p, glory diff, paired t, t p.
  let
    decided = row.w + row.l
    winPct = if row.n > 0: 100.0 * row.w.float / row.n.float else: 0.0
    (lo, hi) = wilson(row.w, row.n)
    winZ = if decided > 0: (row.w - row.l).float / sqrt(decided.float) else: 0.0
  var diffs: seq[float]
  for i in 0 ..< row.n:
    diffs.add row.ours[i] - row.theirs[i]
  let
    d = mean(diffs)
    sd = sqrt(variance(diffs))
    t = if row.n > 1 and sd > 0: d / (sd / sqrt(row.n.float)) else: 0.0
  (winPct, lo, hi, winZ, twoSided(winZ), d, t, twoSided(t))

proc verdict(z, p: float): string =
  ## Names the direction when the test is significant at 5%.
  if p >= 0.05:
    "not significant"
  elif z > 0:
    "ahead"
  else:
    "behind"

proc main() =
  var
    tags: seq[string]
    htmlPath, mdPath: string
  var
    i = 0
    fast = false
  let params = commandLineParams()
  while i < params.len:
    if params[i] == "--fast":
      fast = true
    elif params[i] == "--html" and i + 1 < params.len:
      htmlPath = params[i + 1]
      inc i
    elif params[i] == "--md" and i + 1 < params.len:
      mdPath = params[i + 1]
      inc i
    else:
      tags.add params[i]
    inc i
  if tags.len == 0:
    quit("usage: pw_h2h [--fast] <tag>... [--html path] [--md path]", 2)
  var
    rows = initOrderedTable[string, Row]()
    pooled = Row(rival: "all three")
  for tag in tags:
    for e in (if fast: loadFast(tag) else: load(tag)):
      if e.rival notin rows:
        rows[e.rival] = Row(rival: e.rival)
      rows[e.rival].add e
      pooled.add e
  var ordered = toSeq(rows.values)
  ordered.add pooled
  var md = &"# zhar vs the top three, hosted XP ({tags.join(\", \")})\n\n"
  md.add "Win test: binomial z of wins against losses (draws left out), two-sided p. Score test: paired t on our glory minus theirs per episode (a loss scores 0).\n\n"
  md.add "| rival | n | W-D-L | win % | 95% Wilson | win z | p | our glory | their glory | diff | paired t | p | verdict |\n"
  md.add "|---|---:|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---|\n"
  var html = """<!DOCTYPE html><html><head><meta charset="utf-8"><title>Paintbot head to head</title>
<style>
body { font-family: Georgia, serif; max-width: 70rem; margin: 2rem auto; padding: 0 1rem; color: #111; background: #fffff8; }
table { border-collapse: collapse; width: 100%; font-size: 0.95rem; }
th, td { padding: 0.35rem 0.6rem; border-bottom: 1px solid #ddd; text-align: right; }
th { border-bottom: 2px solid #333; }
td:first-child, th:first-child, td.text, th.text { text-align: left; }
tr.behind td { background: #f6dede; }
tr.ahead td { background: #e4f0e2; }
tr.pooled td { font-weight: 600; border-top: 2px solid #333; }
p.note { color: #555; font-size: 0.9rem; }
</style></head><body>
"""
  html.add &"<h1>zhar vs the top three</h1><p class=\"note\">Hosted XP tags: {tags.join(\", \")}. Win test: binomial z of wins against losses (draws left out), two-sided p. Score test: paired t on our glory minus theirs per episode (a loss scores 0). Red rows: significantly behind at 5%; green: significantly ahead.</p>\n"
  html.add "<table><tr><th class=\"text\">rival</th><th>n</th><th>W-D-L</th><th>win %</th><th>95% Wilson</th><th>win z</th><th>p</th><th>our glory</th><th>their glory</th><th>diff</th><th>paired t</th><th>p</th><th class=\"text\">verdict</th></tr>\n"
  for row in ordered:
    let
      (winPct, lo, hi, winZ, winP, d, t, tP) = stats(row)
      winVerdict = verdict(winZ, winP)
      scoreVerdict = verdict(t, tP)
      summary = &"win {winVerdict}, score {scoreVerdict}"
      cls =
        if row.rival == "all three":
          "pooled"
        elif winVerdict == "behind" or scoreVerdict == "behind":
          "behind"
        elif winVerdict == "ahead" and scoreVerdict == "ahead":
          "ahead"
        else:
          ""
    md.add &"| {row.rival} | {row.n} | {row.w}-{row.d}-{row.l} | {winPct:.1f} | [{lo:.2f}, {hi:.2f}] | {winZ:.2f} | {winP:.3f} | {mean(row.ours):.0f} | {mean(row.theirs):.0f} | {d:+.0f} | {t:.2f} | {tP:.3f} | {summary} |\n"
    html.add &"<tr class=\"{cls}\"><td class=\"text\">{row.rival}</td><td>{row.n}</td><td>{row.w}-{row.d}-{row.l}</td><td>{winPct:.1f}</td><td>[{lo:.2f}, {hi:.2f}]</td><td>{winZ:.2f}</td><td>{winP:.3f}</td><td>{mean(row.ours):.0f}</td><td>{mean(row.theirs):.0f}</td><td>{d:+.0f}</td><td>{t:.2f}</td><td>{tP:.3f}</td><td class=\"text\">{summary}</td></tr>\n"
  html.add "</table></body></html>\n"
  echo md
  if mdPath.len > 0:
    writeFile(mdPath, md)
  if htmlPath.len > 0:
    writeFile(htmlPath, html)

main()
