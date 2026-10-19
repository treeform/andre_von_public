## Behaviour statistics over the CSV written by behavior.nim: conditional
## action distributions of the argmax MMONet seats, grouped by situation,
## to distil scripted rules. Prints tables; no scoring.
##
##   nim r -d:release behavior_stats.nim <behavior_all.csv>

import
  std/[algorithm, os, strutils, tables]

type
  Row = seq[int]
  Columns = Table[string, int]

const ActionNames = ["down", "up", "right", "left", "noop", "attack", "6",
  "ui", "k1", "k2", "k3", "k4", "k5", "k6", "k7", "k8", "k9", "k0",
  "minus", "equals", "buy", "sell", "rdown", "rup", "rright", "rleft"]

proc load(path: string): (Columns, seq[Row]) =
  var columns: Columns
  var rows: seq[Row]
  var first = true
  for line in lines(path):
    if first:
      first = false
      var i = 0
      for name in line.split(','):
        columns[name] = i
        inc i
      continue
    let parts = line.split(',')
    var row = newSeq[int](parts.len - 1)
    for i in 1 ..< parts.len:
      row[i - 1] = parseInt(parts[i])
    rows.add(row)
  (columns, rows)

var col: Columns

proc v(row: Row, name: string): int =
  row[col[name] - 1]

proc moveDelta(action: int): (int, int) =
  var a = action
  if a >= 22: a -= 22
  case a
  of 0: (1, 0)
  of 1: (-1, 0)
  of 2: (0, 1)
  of 3: (0, -1)
  else: (0, 0)

proc isMove(action: int): bool =
  action <= 3 or (action >= 22 and action <= 25)

proc towardness(action: int, dr, dc: int): string =
  ## Does a move reduce the manhattan distance to (dr, dc)?
  if not isMove(action): return "-"
  let (mr, mc) = moveDelta(action)
  let before = abs(dr) + abs(dc)
  let after = abs(dr - mr) + abs(dc - mc)
  if after < before: "toward"
  elif after > before: "away"
  else: "side"

proc actionClass(row: Row): string =
  let a = row.v("action")
  if a == 5: return "attack"
  if a == 4: return "noop"
  if isMove(a):
    let prefix = if a >= 22: "run-" else: "walk-"
    if row.v("e1dist") <= 4:
      return prefix & towardness(a, row.v("e1dr"), row.v("e1dc")) & "-enemy"
    if row.v("udr") != 0 or row.v("udc") != 0:
      return prefix & towardness(a, row.v("udr"), row.v("udc")) & "-uprsrc"
    if row.v("idr") != 0 or row.v("idc") != 0:
      return prefix & towardness(a, row.v("idr"), row.v("idc")) & "-item"
    return prefix & "free"
  if a >= 8 and a <= 16:
    let slot = a - 8
    let id = row.v("inv" & $slot)
    if id == 0: return "key-empty"
    let kind = id mod 17
    let eq = row.v("eq" & $slot)
    var name: string
    case kind
    of 1: name = "helm"
    of 2: name = "chest"
    of 3: name = "legs"
    of 4: name = "sword"
    of 5: name = "bow"
    of 6: name = "tool"
    of 11: name = "herb"
    else: name = "item" & $kind
    if eq == 1:
      name.add("(equipped)")
    return "key-" & name
  ActionNames[a]

proc table(title: string, rows: seq[Row], keyOf: proc(r: Row): string,
           minCount = 200) =
  echo ""
  echo "## ", title
  var counts: Table[string, CountTable[string]]
  var totals: CountTable[string]
  for r in rows:
    let k = keyOf(r)
    if k == "": continue
    counts.mgetOrPut(k, initCountTable[string]()).inc(actionClass(r))
    totals.inc(k)
  var keys: seq[string]
  for k in totals.keys: keys.add(k)
  keys.sort()
  for k in keys:
    if totals[k] < minCount: continue
    var items: seq[(string, int)]
    for a, n in counts[k]: items.add((a, n))
    items.sort(proc(x, y: (string, int)): int = y[1] - x[1])
    var line = k.alignLeft(34) & ($totals[k]).align(7) & "  "
    var shown = 0
    for (a, n) in items:
      if shown >= 6: break
      line.add(a & " " & formatFloat(100.0 * n.float / totals[k].float,
        ffDecimal, 0) & "%  ")
      inc shown
    echo line

proc bucketHp(hp: int): string =
  if hp < 30: "hp<30" elif hp < 60: "hp30-59" else: "hp60+"

proc main() =
  let (columns, rows) = load(paramStr(1))
  col = columns
  echo "rows ", rows.len
  var overall: CountTable[string]
  for r in rows: overall.inc(actionClass(r))
  echo "## overall action classes"
  var items: seq[(string, int)]
  for a, n in overall: items.add((a, n))
  items.sort(proc(x, y: (string, int)): int = y[1] - x[1])
  for (a, n) in items:
    echo a.alignLeft(28), ($n).align(8), "  ",
      formatFloat(100.0 * n.float / rows.len.float, ffDecimal, 1), "%"

  table("ui mode (0 play, 1 buy-tier, 2 buy-item, 3 sell-select, 4 sell-price)",
        rows, proc(r: Row): string = "ui=" & $r.v("ui"))
  let play = proc(r: Row): bool = r.v("ui") == 0
  var playRows: seq[Row]
  for r in rows:
    if play(r): playRows.add(r)

  table("nearest enemy distance x delta (play mode)", playRows,
        proc(r: Row): string =
          let d = r.v("e1dist")
          let db = (if d >= 99: "none" elif d <= 1: "d1" elif d == 2: "d2"
                    elif d <= 4: "d3-4" else: "d5+")
          db & " delta" & $min(r.v("e1delta"), 2))
  table("adjacent enemy: hp bucket x enemy hp bucket x delta", playRows,
        proc(r: Row): string =
          if r.v("e1dist") > 1: return ""
          bucketHp(r.v("hp")) & " ehp" & $r.v("e1hp") & " delta" &
            $min(r.v("e1delta"), 2))
  table("adjacent enemy: in_combat x held kind", playRows,
        proc(r: Row): string =
          if r.v("e1dist") > 1: return ""
          "combat" & $min(r.v("inCombat"), 1) & " held" & $r.v("heldKind"))
  table("enemy at distance 2-4: delta x hp bucket x count within 4",
        playRows,
        proc(r: Row): string =
          let d = r.v("e1dist")
          if d < 2 or d > 4: return ""
          "delta" & $min(r.v("e1delta"), 2) & " " & bucketHp(r.v("hp")) &
            " n4=" & $min(r.v("nEnemy4"), 3))
  table("enemy at distance 2-4: same row/col (bow lane) x delta", playRows,
        proc(r: Row): string =
          let d = r.v("e1dist")
          if d < 2 or d > 4: return ""
          let lane = r.v("e1dr") == 0 or r.v("e1dc") == 0
          "lane" & $int(lane) & " delta" & $min(r.v("e1delta"), 2))
  table("no enemy within 4: prof-leveling resource in view x held tool tier",
        playRows,
        proc(r: Row): string =
          if r.v("e1dist") <= 4: return ""
          let up = r.v("udr") != 0 or r.v("udc") != 0
          "up=" & $int(up) & " tool" & $r.v("heldTier") & " kind" &
            $r.v("heldKind"))
  table("no enemy within 4: hp bucket x herbs", playRows,
        proc(r: Row): string =
          if r.v("e1dist") <= 4: return ""
          bucketHp(r.v("hp")) & " herbs" & $min(r.v("herbs"), 2))
  table("low hp (<40) anywhere: herbs x enemy distance", playRows,
        proc(r: Row): string =
          if r.v("hp") >= 40: return ""
          let d = r.v("e1dist")
          "herbs" & $min(r.v("herbs"), 2) & " e" &
            (if d >= 99: "none" elif d <= 1: "1" elif d <= 4: "2-4" else: "5+"))
  table("inventory: free slots x gold", playRows,
        proc(r: Row): string =
          "free" & $min(r.v("invFree"), 3) & " gold" &
            (if r.v("gold") < 10: "<10" elif r.v("gold") < 30: "10-29"
             else: "30+"))
  table("tool on ground within 3 (no enemy within 2)", playRows,
        proc(r: Row): string =
          if r.v("e1dist") <= 2: return ""
          let td = abs(r.v("tdr")) + abs(r.v("tdc"))
          if r.v("tTier") == 0 or td > 3: return ""
          "toolTier" & $r.v("tTier") & " held" & $r.v("heldTier") & " inv" &
            $r.v("invToolTier"))
  table("held item kind x combat level bucket (no enemy within 4)", playRows,
        proc(r: Row): string =
          if r.v("e1dist") <= 4: return ""
          "held" & $r.v("heldKind") & " comb" &
            (if r.v("comb") < 4: "<4" elif r.v("comb") < 8: "4-7"
             elif r.v("comb") < 12: "8-11" else: "12+"))
  table("player within 4: delta x hp", playRows,
        proc(r: Row): string =
          if r.v("nPlayer4") == 0: return ""
          "pdelta" & $min(r.v("p1delta"), 2) & " " & bucketHp(r.v("hp")))
  table("previous action x current (movement persistence)", playRows,
        proc(r: Row): string =
          let p = r.v("prevAction")
          if not isMove(p): return ""
          "prev=" & ActionNames[p] & " anim" & $r.v("anim"))

main()

## Raw-key tables for interface modes and ranged attacks.

proc rawTable(title: string, rows: seq[Row], keyOf: proc(r: Row): string,
              minCount = 100) =
  echo ""
  echo "## ", title
  var counts: Table[string, CountTable[string]]
  var totals: CountTable[string]
  for r in rows:
    let k = keyOf(r)
    if k == "": continue
    counts.mgetOrPut(k, initCountTable[string]()).inc(
      ActionNames[r.v("action")])
    totals.inc(k)
  var keys: seq[string]
  for k in totals.keys: keys.add(k)
  keys.sort()
  for k in keys:
    if totals[k] < minCount: continue
    var items: seq[(string, int)]
    for a, n in counts[k]: items.add((a, n))
    items.sort(proc(x, y: (string, int)): int = y[1] - x[1])
    var line = k.alignLeft(34) & ($totals[k]).align(7) & "  "
    var shown = 0
    for (a, n) in items:
      if shown >= 8: break
      line.add(a & " " & formatFloat(100.0 * n.float / totals[k].float,
        ffDecimal, 0) & "%  ")
      inc shown
    echo line

proc extra() =
  let (columns, rows) = load(paramStr(1))
  col = columns
  rawTable("raw keys in buy-tier mode (ui=1) x held tool tier x gold", rows,
    proc(r: Row): string =
      if r.v("ui") != 1: return ""
      "held" & $r.v("heldTier") & " invTool" & $r.v("invToolTier") &
        " gold" & (if r.v("gold") < 10: "<10" elif r.v("gold") < 30: "10-29"
                   else: "30+"))
  rawTable("raw keys in buy-item mode (ui=2) x market tier", rows,
    proc(r: Row): string =
      if r.v("ui") != 2: return ""
      "tier" & $r.v("marketTier") & " prof" &
        (if r.v("prof") < 8: "<8" elif r.v("prof") < 16: "8-15" else: "16+"))
  rawTable("raw keys in sell modes (ui=3,4)", rows,
    proc(r: Row): string =
      if r.v("ui") < 3: return ""
      "ui" & $r.v("ui") & " free" & $min(r.v("invFree"), 3))
  rawTable("BUY press context (play mode): gold x held tool tier x prof", rows,
    proc(r: Row): string =
      if r.v("ui") != 0 or r.v("action") != 20: return ""
      "gold" & (if r.v("gold") < 10: "<10" elif r.v("gold") < 30: "10-29"
                else: "30+") & " held" & $r.v("heldTier") & " prof" &
        (if r.v("prof") < 8: "<8" elif r.v("prof") < 16: "8-15" else: "16+"))
  rawTable("attack press: nearest enemy geometry x held kind", rows,
    proc(r: Row): string =
      if r.v("ui") != 0 or r.v("action") != 5: return ""
      let d = r.v("e1dist")
      let lane = r.v("e1dr") == 0 or r.v("e1dc") == 0
      "held" & $r.v("heldKind") & " e" &
        (if d >= 99: "none" elif d <= 1: "1" elif d <= 4: "2-4" else: "5+") &
        " lane" & $int(lane) & " combat" & $min(r.v("inCombat"), 1))
  rawTable("herb key press context", rows,
    proc(r: Row): string =
      let a = r.v("action")
      if r.v("ui") != 0 or a < 8 or a > 16: return ""
      let id = r.v("inv" & $(a - 8))
      if id mod 17 != 11: return ""
      bucketHp(r.v("hp")) & " e" & (if r.v("e1dist") <= 1: "1" elif r.v("e1dist") <= 4: "2-4" else: "far"))
  rawTable("hp<40, herbs>0, play mode: what is pressed", rows,
    proc(r: Row): string =
      if r.v("ui") != 0 or r.v("hp") >= 40 or r.v("herbs") == 0: return ""
      "e" & (if r.v("e1dist") <= 1: "1" elif r.v("e1dist") <= 4: "2-4" else: "far"))

extra()

proc earlyLife() =
  let (columns, rows) = load(paramStr(1))
  col = columns
  var playRows: seq[Row]
  for r in rows:
    if r.v("ui") == 0 and r.v("comb") <= 3: playRows.add(r)
  table("comb<=3: nearest enemy dist x delta", playRows,
        proc(r: Row): string =
          let d = r.v("e1dist")
          let db = (if d >= 99: "none" elif d <= 1: "d1" elif d == 2: "d2"
                    elif d <= 4: "d3-4" else: "d5+")
          db & " delta" & $min(r.v("e1delta"), 3), 50)
  table("comb<=3 adjacent enemy: my hp x enemy hp x delta", playRows,
        proc(r: Row): string =
          if r.v("e1dist") > 1: return ""
          bucketHp(r.v("hp")) & " ehp" & $r.v("e1hp") & " delta" &
            $min(r.v("e1delta"), 3), 50)
  rawTable("comb<=3, no enemy within 4: raw actions x lifeTick bucket", playRows,
    proc(r: Row): string =
      if r.v("e1dist") <= 4: return ""
      "life" & (if r.v("lifeTick") < 50: "<50" elif r.v("lifeTick") < 200: "50-199" else: "200+"), 50)

earlyLife()
