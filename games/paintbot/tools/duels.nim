## Duel anatomy from re-simulated Season 2 event streams: for every pair
## that exchanged gun damage, who landed the first hit, who died first, and
## how many hits each side landed. Aggregates: first-hitter kill share,
## share of kills where the victim never hit back, mean hits per duel.
##
##   nim r games/paintbot/tools/duels.nim EVENTS.jsonl ...

import std/[algorithm, json, os, strformat, strutils, tables]

type Duel = object
  first: int         # seat that hit first
  hits: array[2, int]
  loser: int         # -1 while nobody died

proc key(a, b: int): (int, int) = (if a < b: (a, b) else: (b, a))

proc main() =
  var firstHitterWins, kills, oneSided, duels, totalHits = 0
  var duelsWithKill = 0
  var focusSeat = -1
  var focusDeaths, focusOneSided, focusFirstHitLost = 0
  var focusTicksToDie: seq[int]
  var killers = initTable[int, int]()
  var files: seq[string]
  for i in 1 .. paramCount():
    let a = paramStr(i)
    if a.startsWith("--seat="): focusSeat = parseInt(a[7 .. ^1])
    else: files.add a
  for path in files:
    var table = initTable[(int, int), Duel]()
    var firstHurt = -1
    for line in lines(path):
      if line.len == 0: continue
      let e = parseJson(line)
      if e{"type"}.getStr == "summary": continue
      let kind = e{"kind"}.getStr
      let source = e{"source"}.getInt(-1)
      let target = e{"target"}.getInt(-1)
      if kind == "death" and source == focusSeat:
        inc focusDeaths
        inc killers.mgetOrPut(target, 0)
        if firstHurt >= 0: focusTicksToDie.add(e{"tick"}.getInt - firstHurt)
      if source notin 0 .. 15 or target notin 0 .. 15 or source == target: continue
      if kind == "damage" and e{"weapon"}.getStr == "gun":
        if target == focusSeat and firstHurt < 0: firstHurt = e{"tick"}.getInt
        let k = key(source, target)
        if not table.hasKey(k):
          table[k] = Duel(first: source, loser: -1)
        var d = table[k]
        inc d.hits[(if source == k[0]: 0 else: 1)]
        table[k] = d
      elif kind == "kill":
        let k = key(source, target)
        if table.hasKey(k):
          var d = table[k]
          if d.loser < 0:
            d.loser = target
            inc kills
            if d.first == source: inc firstHitterWins
            let victimHits = d.hits[(if target == k[0]: 0 else: 1)]
            if victimHits == 0: inc oneSided
            if target == focusSeat:
              if victimHits == 0: inc focusOneSided
              if d.first == source: inc focusFirstHitLost
          table[k] = d
    for k, d in table:
      inc duels
      totalHits += d.hits[0] + d.hits[1]
      if d.loser >= 0: inc duelsWithKill
  echo &"duels {duels}  with a kill {duelsWithKill}  kills {kills}"
  echo &"first-hitter wins {firstHitterWins} of {kills} ({100 * firstHitterWins div max(1, kills)}%)"
  echo &"victim never hit back {oneSided} of {kills} ({100 * oneSided div max(1, kills)}%)"
  echo &"mean hits per duel {totalHits.float / max(1, duels).float:.2f}"
  if focusSeat >= 0:
    var ticks = 0
    for t in focusTicksToDie: ticks += t
    echo &"seat {focusSeat}: deaths {focusDeaths}, never fired back {focusOneSided}, killer hit first {focusFirstHitLost}, mean ticks first hit->death {ticks.float / max(1, focusTicksToDie.len).float:.0f}"
    var ks: seq[(int, int)]
    for k, v in killers: ks.add (v, k)
    ks.sort(proc(a, b: (int, int)): int = cmp(b[0], a[0]))
    echo "  killers (seat: count): ", ks

main()
