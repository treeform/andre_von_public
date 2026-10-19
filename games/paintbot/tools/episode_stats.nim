## Per-seat combat profile of Season 2 episodes from the engine's
## re-simulated event stream (coworld-ctf tools/extract_events.nim --out).
##
##   nim r games/paintbot/tools/episode_stats.nim EVENTS.jsonl ...
##
## For every file: per seat shots, hits dealt, damage taken by weapon,
## kills, death tick and killer, glory deeds; then an aggregate per player
## name (the summary row's slot_address) across all files: games, kills,
## deaths, shots, hit rate, mean death order (1 = died first, 16 = last),
## wins. This is the isolation tool: it says what a seat did, not what it
## scored.

import std/[algorithm, json, os, strformat, strutils, tables]

type
  Seat = object
    name: string
    shots, hits, kills, deeds: int
    closing, firstBlood, longshot, joint: int
    gunTaken, zoneTaken: int
    deathTick: int
    killer: int
  Agg = object
    games, kills, deaths, shots, hits, wins: int
    closing, firstBlood, longshot, joint: int
    orderSum: int
    aliveTicks: int

proc profile(path: string): seq[Seat] =
  var seats = newSeq[Seat](16)
  for i in 0 ..< 16: seats[i].deathTick = -1
  var ticks = 0
  for line in lines(path):
    if line.len == 0: continue
    let e = parseJson(line)
    if e{"type"}.getStr == "summary":
      ticks = e{"ticks"}.getInt
      let names = e{"slot_address"}
      if names != nil:
        for i, n in names.getElems():
          if i < 16: seats[i].name = n.getStr
      continue
    let kind = e{"kind"}.getStr
    let source = e{"source"}.getInt(-1)
    let target = e{"target"}.getInt(-1)
    case kind
    of "shot":
      if source in 0 .. 15: inc seats[source].shots
    of "damage":
      if target in 0 .. 15:
        if e{"weapon"}.getStr == "zone": inc seats[target].zoneTaken
        else: inc seats[target].gunTaken
      if source in 0 .. 15 and e{"weapon"}.getStr == "gun": inc seats[source].hits
    of "kill":
      if source in 0 .. 15: inc seats[source].kills
    of "death":
      # death and downed rows carry the victim in `source`, the killer in `target`.
      if source in 0 .. 15:
        seats[source].deathTick = e{"tick"}.getInt
        seats[source].killer = target
    of "glory_deed":
      if source in 0 .. 15:
        inc seats[source].deeds
        case e{"weapon"}.getStr
        of "dClosingTime": inc seats[source].closing
        of "dFirstBlood": inc seats[source].firstBlood
        of "dLongshotKill": inc seats[source].longshot
        of "dJointAct": inc seats[source].joint
        else: discard
    else: discard
  for s in seats.mitems:
    if s.deathTick < 0: s.deathTick = ticks + 1
  seats

proc main() =
  if paramCount() < 1: quit("usage: episode_stats EVENTS.jsonl ...", 2)
  var agg = initTable[string, Agg]()
  for i in 1 .. paramCount():
    let seats = profile(paramStr(i))
    var order = newSeq[int](16)
    var idx = newSeq[int]()
    for s in 0 ..< 16: idx.add s
    idx.sort(proc(a, b: int): int = cmp(seats[a].deathTick, seats[b].deathTick))
    for rank, s in idx: order[s] = rank + 1
    let maxTick = seats[idx[^1]].deathTick
    echo "## ", paramStr(i).extractFilename
    for s in 0 ..< 16:
      let st = seats[s]
      let died = if st.deathTick >= maxTick: "alive" else: $st.deathTick
      echo &"  seat {s:2d} {st.name:28s} shots {st.shots:3d} hits {st.hits:3d} kills {st.kills} deeds {st.deeds:2d} taken gun {st.gunTaken} zone {st.zoneTaken} death {died} by {st.killer} order {order[s]}"
      var a = agg.getOrDefault(st.name)
      inc a.games
      a.kills += st.kills; a.shots += st.shots; a.hits += st.hits
      a.closing += st.closing; a.firstBlood += st.firstBlood
      a.longshot += st.longshot; a.joint += st.joint
      if st.deathTick < maxTick: inc a.deaths else: inc a.wins
      a.orderSum += order[s]
      a.aliveTicks += min(st.deathTick, maxTick)
      agg[st.name] = a
  echo "## aggregate by player"
  var names: seq[string]
  for k in agg.keys: names.add k
  names.sort(proc(a, b: string): int = cmp(agg[b].wins * 1000 + agg[b].orderSum div max(1, agg[b].games), agg[a].wins * 1000 + agg[a].orderSum div max(1, agg[a].games)))
  for n in names:
    let a = agg[n]
    let g = max(1, a.games).float
    let hitRate = if a.shots > 0: a.hits.float / a.shots.float else: 0.0
    echo &"  {n:28s} games {a.games:2d} wins {a.wins} kills/g {a.kills.float / g:.2f} shots/g {a.shots.float / g:5.1f} hit {hitRate:.2f} death order {a.orderSum.float / g:4.1f} alive/g {a.aliveTicks.float / g:6.0f} closing/g {a.closing.float / g:.2f} firstblood {a.firstBlood} longshot {a.longshot} joint/g {a.joint.float / g:.2f}"

main()
