## Match analyzer for the local BASIC ladder. Reads the engine's duel logs
## (one directory per match holding events.jsonl and summary.json) and
## reports, from OUR side (the seats whose script name contains `mine`):
## outcome, kills for/against by cause, our deaths by cause and layer,
## hook accuracy by distance band, rune share, and the dodge block. Then
## it splits the games into wins/losses/draws and prints the means per
## group, so the discriminators between a lost and a won game stand out.
##
##   nim r --hints:off games/pudge-wars/bas/analyze.nim <logroot> [mine=myasnik]
##
## <logroot> is searched recursively for summary.json files.

import std/[os, json, strutils, strformat, tables, algorithm, math]

type
  Game = object
    dir: string
    ourTeam: string
    outcome: string        # win / loss / draw
    ourKills, theirKills: int
    killsFor: CountTable[string]
    killsAgainst: CountTable[string]
    deathLayer: CountTable[string]
    hooks, landed: int
    band: Table[string, (int, int)]
    runesOurs, runesTheirs: int
    aimedAtUs, hitUs: int
    ourDeathTicks: seq[int]
    firstDeathTick: int

proc newGame(dir: string): Game =
  result.dir = dir
  result.killsFor = initCountTable[string]()
  result.killsAgainst = initCountTable[string]()
  result.deathLayer = initCountTable[string]()
  result.band = initTable[string, (int, int)]()
  result.firstDeathTick = -1

proc analyze(dir, mine: string): Game =
  var game = newGame(dir)
  let summary = parseJson(readFile(dir / "summary.json"))
  var teams = initTable[int, string]()
  var scripts = initTable[int, string]()
  var lastLayer = initTable[int, int]()
  for line in lines(dir / "events.jsonl"):
    if line.len == 0: continue
    let ev = parseJson(line)
    let kind = ev{"ev"}.getStr
    case kind
    of "match_start":
      for p in ev{"players"}:
        let id = p{"id"}.getInt
        teams[id] = p{"team"}.getStr
        scripts[id] = p{"script"}.getStr
        if mine in p{"script"}.getStr:
          game.ourTeam = p{"team"}.getStr
    of "state":
      for q in ev{"p"}:
        lastLayer[q{"id"}.getInt] = q{"lay"}.getInt(-1)
    of "kill":
      let killer = ev{"killer"}.getInt(-1)
      let victim = ev{"victim"}.getInt(-1)
      let cause = ev{"cause"}.getStr
      if teams.getOrDefault(killer) == game.ourTeam:
        game.killsFor.inc cause
      if teams.getOrDefault(victim) == game.ourTeam:
        game.killsAgainst.inc cause
        let lay = lastLayer.getOrDefault(victim, -1)
        game.deathLayer.inc(
          if lay == 2: "river"
          elif (lay == 0 and game.ourTeam == "west") or (lay == 1 and game.ourTeam == "east"): "home"
          else: "enemy")
        game.ourDeathTicks.add ev{"t"}.getInt
        if game.firstDeathTick < 0: game.firstDeathTick = ev{"t"}.getInt
    of "rune_taken":
      if teams.getOrDefault(ev{"id"}.getInt) == game.ourTeam: inc game.runesOurs
      else: inc game.runesTheirs
    else: discard
  let score = summary{"score"}
  let west = score{"west"}.getInt
  let east = score{"east"}.getInt
  if game.ourTeam == "west":
    game.ourKills = west; game.theirKills = east
  else:
    game.ourKills = east; game.theirKills = west
  game.outcome =
    if game.ourKills > game.theirKills: "win"
    elif game.ourKills < game.theirKills: "loss"
    else: "draw"
  for p in summary{"players"}:
    if not (mine in p{"script"}.getStr): continue
    game.hooks += p{"hooksThrown"}.getInt
    game.landed += int(round(p{"accuracy"}.getFloat * p{"hooksThrown"}.getFloat))
    for band, pair in p{"hitRateByDist"}:
      let (h, n) = game.band.getOrDefault(band, (0, 0))
      game.band[band] = (h + pair[0].getInt, n + pair[1].getInt)
    let dodge = p{"dodge"}
    game.aimedAtUs += dodge{"hooksAimedAtMe"}.getInt
    game.hitUs += dodge{"hit"}.getInt
  game

proc pct(a, b: int): string =
  if b == 0: "-" else: &"{100 * a div b}%"

proc main() =
  if paramCount() < 1:
    quit("usage: analyze <logroot> [mine=myasnik]", 2)
  let root = paramStr(1)
  let mine = if paramCount() >= 2: paramStr(2) else: "myasnik"
  var games: seq[Game]
  for path in walkDirRec(root):
    if path.endsWith("summary.json"):
      games.add analyze(path.parentDir, mine)
  games.sort(proc(a, b: Game): int = cmp(a.dir, b.dir))
  echo &"{games.len} games"
  echo "dir | outcome | ours-theirs | kills for (cause) | deaths (cause) | death layer | hooks landed | runes ours-theirs | hooks at us hit"
  for g in games:
    var kf, ka, dl: seq[string]
    for k, v in g.killsFor: kf.add &"{k}:{v}"
    for k, v in g.killsAgainst: ka.add &"{k}:{v}"
    for k, v in g.deathLayer: dl.add &"{k}:{v}"
    echo &"{g.dir.extractFilename} | {g.outcome} | {g.ourKills}-{g.theirKills} | {kf.join(\",\")} | {ka.join(\",\")} | {dl.join(\",\")} | {g.landed}/{g.hooks} | {g.runesOurs}-{g.runesTheirs} | {g.hitUs}/{g.aimedAtUs}"
  for group in ["win", "loss", "draw"]:
    var n = 0
    var kills, deaths, hooks, landed, runesO, runesT, aimed, hit, enemyDeaths, riverDeaths, firstDeath = 0
    var causesFor = initCountTable[string]()
    var causesAgainst = initCountTable[string]()
    var bands = initTable[string, (int, int)]()
    for g in games:
      if g.outcome != group: continue
      inc n
      kills += g.ourKills; deaths += g.theirKills
      hooks += g.hooks; landed += g.landed
      runesO += g.runesOurs; runesT += g.runesTheirs
      aimed += g.aimedAtUs; hit += g.hitUs
      enemyDeaths += g.deathLayer.getOrDefault("enemy")
      riverDeaths += g.deathLayer.getOrDefault("river")
      if g.firstDeathTick >= 0: firstDeath += g.firstDeathTick
      for k, v in g.killsFor: causesFor.inc(k, v)
      for k, v in g.killsAgainst: causesAgainst.inc(k, v)
      for band, pair in g.band:
        let (h, m) = bands.getOrDefault(band, (0, 0))
        bands[band] = (h + pair[0], m + pair[1])
    if n == 0: continue
    var cf, ca, bl: seq[string]
    for k, v in causesFor: cf.add &"{k}:{v}"
    for k, v in causesAgainst: ca.add &"{k}:{v}"
    var keys: seq[string]
    for k in bands.keys: keys.add k
    keys.sort()
    for k in keys: bl.add &"{k}:{pct(bands[k][0], bands[k][1])}"
    echo &"\n== {group.toUpperAscii} (n={n}): kills {kills.float / n.float:.2f}/game, deaths {deaths.float / n.float:.2f}/game, " &
      &"hooks {hooks.float / n.float:.1f}/game landed {pct(landed, hooks)}, runes {runesO.float / n.float:.1f} vs {runesT.float / n.float:.1f}, " &
      &"hooks at us hit {pct(hit, aimed)}, deaths on enemy bank {enemyDeaths} in river {riverDeaths}, first death tick {firstDeath div max(n, 1)}"
    echo &"   kills by cause {cf.join(\" \")} | deaths by cause {ca.join(\" \")} | accuracy by band {bl.join(\" \")}"

main()
