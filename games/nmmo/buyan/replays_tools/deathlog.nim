## Hosted death-trace extractor for the scripted engine. Reads the policy
## log files the coworld CLI downloads (optionally wrapped in one Python
## bytes repr), pulls every "buyan: death agent N trace ..." line, and
## prints per-death rows plus a classification: what the last decision
## was, hp at the end, nearest enemy, and how many of the final ticks were
## spent fleeing. Log evidence only, never a score.
##
##   nim r deathlog.nim <log-file>...

import
  std/[os, strutils, tables]

proc unwrap(text: string): string =
  ## Undo a Python bytes repr (b'...') with its escapes.
  if not (text.startsWith("b'") or text.startsWith("b\"")):
    return text
  var i = 2
  while i < text.len:
    let ch = text[i]
    if ch == '\\' and i + 1 < text.len:
      let next = text[i + 1]
      case next
      of 'n': result.add('\n'); i += 2
      of 't': result.add('\t'); i += 2
      of 'r': result.add('\r'); i += 2
      of '\\': result.add('\\'); i += 2
      of '\'': result.add('\''); i += 2
      of '"': result.add('"'); i += 2
      of 'x':
        if i + 3 < text.len:
          result.add(char(parseHexInt(text[i + 2 .. i + 3])))
          i += 4
        else:
          i += 2
      else:
        result.add(next); i += 2
    else:
      result.add(ch)
      inc i

type Death = object
  file: string
  agent: string
  steps: seq[string]

proc parseStep(step: string): (string, int, string, bool) =
  ## Returns (branch, hp, nearest, inCombat) from "t12 flee a24 hp45 c3/p8 e2:1:4 cb n3".
  var branch = ""
  var hp = -1
  var near = "-"
  var combat = false
  for part in step.split(' '):
    if part.len == 0: continue
    if branch == "" and not part.startsWith("t"):
      branch = part
    elif part.startsWith("hp"):
      hp = parseInt(part[2 .. ^1])
    elif part.startsWith("e") and part.len > 1 and part[1] in {'0'..'9', '-'}:
      near = part[1 .. ^1]
    elif part == "cb":
      combat = true
  (branch, hp, near, combat)

proc main() =
  var deaths: seq[Death]
  for path in commandLineParams():
    let text = unwrap(readFile(path))
    for line in text.splitLines():
      let marker = line.find("buyan: death agent ")
      if marker < 0: continue
      let rest = line[marker + "buyan: death agent ".len .. ^1]
      let traceAt = rest.find(" trace ")
      if traceAt < 0: continue
      var d = Death(file: path.extractFilename, agent: rest[0 ..< traceAt])
      for step in rest[traceAt + 7 .. ^1].split(" | "):
        d.steps.add(step.strip())
      deaths.add(d)
  echo "deaths ", deaths.len, " in ", commandLineParams().len, " logs"
  var lastBranch: CountTable[string]
  var fleeHeavy = 0
  var fullHp = 0
  var lowHp = 0
  var nearDelta: CountTable[string]
  for d in deaths:
    if d.steps.len == 0: continue
    let (branch, hp, near, _) = parseStep(d.steps[^1])
    lastBranch.inc(branch)
    var flees = 0
    for s in d.steps:
      if parseStep(s)[0] == "flee": inc flees
    if flees >= 6: inc fleeHeavy
    if hp >= 90: inc fullHp
    if hp < 40: inc lowHp
    let parts = near.split(':')
    nearDelta.inc(if parts.len >= 2: "d" & parts[0] & " delta" & parts[1] else: near)
  echo "last branch: ", lastBranch
  echo "flee-heavy (>=6 of last 12): ", fleeHeavy, "  full hp (>=90) at last decision: ",
    fullHp, "  low hp (<40): ", lowHp
  echo "nearest enemy at last decision (dist delta): ", nearDelta
  echo ""
  for d in deaths:
    echo d.file[0 .. min(20, d.file.high)], " agent ", d.agent
    for s in d.steps:
      echo "   ", s

main()
