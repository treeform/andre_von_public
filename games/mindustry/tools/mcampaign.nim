## Plays the serpulo campaign in order with the drill bot and keeps a table
## of the sectors it clears and how fast.
##
## nim r -d:release --hints:off tools/mcampaign.nim [--from=N] [--to=N]
##   [--only=name] [--all] [--ticks=N] [--attempts=N] [--parallel=N]
##   [--collect] [--fresh] [--bot=path] [--attack-bot=path] [--uncleared]
##   [--forever] [--bot-for=sector=path]... [--render-only]
##
## The bot (drills/brain.bas) reads each sector itself and plans as it goes,
## playing until the sector is captured, the core falls or the tick budget
## runs out. Results go to campaign.json and campaign.md, replays and
## campaign.html (the table with replay links) to the coworld-mindustry viewer.
## Each sector plays its saved script (drills/levels/NN_sector.bas, the one
## that set its best time) or, not yet cleared, drills/brain.bas; --bot=path
## plays another script, and a capture faster than the record saves it as
## the sector's script (--attack-bot=path plays attack sectors with another
## script, --bot-for=sector=path one sector with its own). --only takes names
## separated by commas. Played in order, it passes over cleared sectors and
## stops at the first sector it does not clear unless --all is given;
## with --all every sector without a result plays, --parallel games at a
## time (--fresh replays them all), and games still running from an earlier
## run are watched, not restarted; with --uncleared every sector not cleared
## yet plays again, and with --forever it plays again as soon as its game
## ends (until it is cleared).
## --collect only rereads the logs of games already played. --to=N plays
## sectors up to N (all by default).
## --render-only refreshes the HTML from saved results without playing games.

import
  std/[algorithm, json, os, osproc, strutils, tables, times]

type
  Sector = object
    name, title: string
    ## Waves to survive; 0 for an attack sector (destroy the enemy cores).
    capture: int

  Row = object
    ## One sector's line in the tables: the latest run's result, the record
    ## (fastest capture ever) and the attempts played over all runs.
    outcome, best, tries, gathered, lost, replay: string
    won, played: bool
    ## The furthest wave reached (of the sector's capture wave), and in an
    ## attack sector the enemy cores destroyed of all (-1 when not known).
    wave, cores, coresAll: int

  Live = object
    ## A sector still in play: waiting for a slot, or its game's progress.
    playing: bool
    tick, wave: int

const
  CampaignCss = staticRead("campaign.css")
  CampaignFonts = [
    ("ETBembo-RomanOSF.otf", staticRead("fonts/ETBembo-RomanOSF.otf")),
    ("ETBembo-DisplayItalic.otf", staticRead("fonts/ETBembo-DisplayItalic.otf")),
    ("ETBembo-SemiBoldOSF.otf", staticRead("fonts/ETBembo-SemiBoldOSF.otf"))
  ]
  Sectors = [
    Sector(name: "groundZero", title: "Ground Zero", capture: 10),
    Sector(name: "frozenForest", title: "Frozen Forest", capture: 15),
    Sector(name: "crateredBattleground", title: "Cratered Battleground",
      capture: 20),
    Sector(name: "biomassFacility", title: "Biomass Synthesis Facility",
      capture: 20),
    Sector(name: "ruinousShores", title: "Ruinous Shores", capture: 30),
    Sector(name: "windsweptIslands", title: "Windswept Islands", capture: 30),
    Sector(name: "stainedMountains", title: "Stained Mountains", capture: 30),
    Sector(name: "fungalPass", title: "Fungal Pass", capture: 0),
    Sector(name: "frontier", title: "Frontier", capture: 0),
    Sector(name: "facility32m", title: "Facility 32 M", capture: 25),
    Sector(name: "saltFlats", title: "Salt Flats", capture: 0),
    Sector(name: "tarFields", title: "Tar Fields", capture: 40),
    Sector(name: "perilousHarbor", title: "Perilous Harbor", capture: 0),
    Sector(name: "infestedCanyons", title: "Infested Canyons", capture: 0),
    Sector(name: "extractionOutpost", title: "Extraction Outpost", capture: 0),
    Sector(name: "coastline", title: "Humid Coastline", capture: 30),
    Sector(name: "taintedWoods", title: "Tainted Woods", capture: 33),
    Sector(name: "impact0078", title: "Impact 0078", capture: 45),
    Sector(name: "nuclearComplex", title: "Nuclear Production Complex",
      capture: 50),
    Sector(name: "overgrowth", title: "Overgrowth", capture: 0),
    Sector(name: "navalFortress", title: "Naval Fortress", capture: 0),
    Sector(name: "desolateRift", title: "Desolate Rift", capture: 18),
    Sector(name: "testingGrounds", title: "Testing Grounds", capture: 33),
    Sector(name: "atolls", title: "Atolls", capture: 0),
    Sector(name: "mycelialBastion", title: "Mycelial Bastion", capture: 0),
    Sector(name: "sunkenPier", title: "Sunken Pier", capture: 50),
    Sector(name: "weatheredChannels", title: "Weathered Channels", capture: 40),
    Sector(name: "littoralShipyard", title: "Littoral Shipyard", capture: 0),
    Sector(name: "planetaryTerminal", title: "Planetary Launch Terminal",
      capture: 0)
  ]
  ViewerUrl = "http://localhost:8769/index.html?replay=replays/"

proc fail(message: string) =
  ## Stops with a campaign error.
  quit("mcampaign: " & message, 1)

proc run(command, directory: string): string =
  ## Runs a shell command and returns its output, failing on a bad exit.
  let (output, code) = execCmdEx(command, workingDir = directory)
  if code != 0:
    fail("command failed (" & $code & "): " & command & "\n" &
      output[max(0, output.len - 2000) .. ^1])
  output

proc clock(ticks: int): string =
  ## Simulated time as minutes and seconds (60 ticks a second).
  let seconds = ticks div 60
  $(seconds div 60) & ":" & align($(seconds mod 60), 2, '0')

proc goal(sector: Sector): string =
  ## The sector's win condition in words.
  if sector.capture > 0:
    "Survive " & $sector.capture & " waves"
  else:
    "Destroy the enemy cores"

proc best(attempts: JsonNode): JsonNode =
  ## The fastest capture, or else the attempt that got furthest.
  for attempt in attempts:
    if result == nil:
      result = attempt
    elif attempt["outcome"].getStr == "captured":
      if result["outcome"].getStr != "captured" or
        attempt["ticks"].getInt < result["ticks"].getInt:
          result = attempt
    elif result["outcome"].getStr != "captured" and
      attempt["wave"].getInt > result["wave"].getInt:
        result = attempt

proc rowFor(sector: Sector, results: JsonNode): Row =
  ## Summarizes a sector: the latest run (its fastest capture, else its
  ## furthest attempt), the record and the attempts over all runs. The
  ## replay link is the record's when it has one.
  if not results.hasKey(sector.name):
    result.outcome = "Not played"
    return
  result.played = true
  let
    entry = results[sector.name]
    attempts = entry["attempts"]
  var times: seq[int]
  for attempt in attempts:
    if attempt["outcome"].getStr == "captured":
      times.add attempt["ticks"].getInt
  times.sort()
  let top = best(attempts)
  result.wave = top["wave"].getInt
  result.cores = top{"cores"}.getInt(-1)
  result.coresAll = top{"coresAll"}.getInt(-1)
  var ofText = " of " & $sector.capture
  if sector.capture == 0:
    ofText =
      if result.coresAll > 0:
        ", " & $result.cores & " of " & $result.coresAll &
          " enemy cores destroyed"
      else: ", enemy cores standing"
  if times.len > 0:
    result.outcome = "Cleared"
  elif top["outcome"].getStr == "core-destroyed":
    result.outcome = "Lost on wave " & $result.wave & ofText
  else:
    result.outcome = "Wave " & $result.wave & ofText & " at the time limit"
  if top.hasKey("error"):
    result.outcome.add " (script error)"
  if attempts.len > 1:
    result.outcome.add " (" & $times.len & " of " & $attempts.len &
      " cleared)"
  if times.len == 0 and entry.hasKey("best"):
    result.outcome = "Cleared before; latest run: " &
      result.outcome.toLowerAscii
  result.gathered = $top["gathered"].getInt
  result.lost = $top["lost"].getInt
  result.replay = top["replay"].getStr
  result.tries = $entry{"tries"}.getInt(attempts.len)
  if entry.hasKey("best"):
    result.won = true
    result.best = clock(entry["best"]["ticks"].getInt)
    if entry["best"]{"replay"}.getStr.len > 0:
      result.replay = entry["best"]["replay"].getStr
  elif times.len > 0:
    result.won = true
    result.best = clock(times[0])

proc writeHtml(path: string, results: JsonNode, live: Table[string, Live],
    maxTicks, shown: int) =
  ## Writes sector records and live progress beside the replay viewer.
  let
    fonts = path.parentDir / "campaign-fonts"
    plannerPath = path.parentDir / "planner-results.html"
    plannerSection =
      if fileExists(plannerPath):
        readFile(plannerPath)
      else:
        ""
    plannerProgressPath = path.parentDir / "planner-progress.html"
    plannerProgress =
      if fileExists(plannerProgressPath):
        readFile(plannerProgressPath)
      else:
        ""
    summaryLabel =
      if plannerSection.len > 0:
        "Earlier scripts: "
      else:
        ""
    recordsHeading =
      if plannerSection.len > 0:
        "Earlier per-sector scripts"
      else:
        "Sector records"
  createDir(fonts)
  for (name, data) in CampaignFonts:
    if not fileExists(fonts / name):
      writeFile(fonts / name, data)
  var
    cleared = 0
    streak = 0
    counting = true
    rows = ""
    playingRows = ""
    queuedRows = ""
    playing = 0
    queued = 0
  for i, sector in Sectors:
    if i >= shown:
      break
    let
      row = rowFor(sector, results)
      sectorCells = "<td class=\"order\">" & $(i + 1) &
        "</td><th scope=\"row\">" & sector.title &
        "<div class=\"goal\">" & sector.goal & "</div></th>"
    if live.hasKey(sector.name):
      let state = live[sector.name]
      var
        status = "Queued"
        elapsed = "&mdash;"
        bar = ""
      if not state.playing:
        inc queued
      else:
        inc playing
        elapsed = clock(state.tick)
        status = "Playing"
        var
          reached = state.tick
          goal = maxTicks
        if sector.capture > 0:
          status.add ": wave " & $state.wave & " of " & $sector.capture
          reached = min(state.wave, sector.capture)
          goal = sector.capture
        bar = "<progress aria-label=\"" & sector.title &
          (if sector.capture > 0: " wave progress" else: " time elapsed") &
          "\" value=\"" & $reached & "\" max=\"" & $goal &
          "\"></progress>"
      let liveRow = "<tr>" & sectorCells &
        "<td class=\"" & (if state.playing: "playing" else: "idle") &
        "\"><div class=\"status\">" & status & "</div>" & bar &
        "</td><td class=\"num\">" & elapsed &
        "</td><td class=\"num\">" & clock(maxTicks) & "</td></tr>\n"
      if state.playing:
        playingRows.add liveRow
      else:
        queuedRows.add liveRow
    var bar = ""
    if row.played:
      # How far the best run got (full once cleared): waves toward the
      # capture wave, or enemy cores destroyed in an attack sector (an empty
      # slot when the run did not report them).
      var reached, goal: int
      if sector.capture > 0:
        goal = sector.capture
        reached = min(row.wave, goal)
      elif row.coresAll > 0:
        goal = row.coresAll
        reached = row.cores
      if row.won:
        goal = max(goal, 1)
        reached = goal
      if goal > 0:
        bar = "<progress class=\"" & (if row.won: "done" else: "short") &
          "\" value=\"" & $reached & "\" max=\"" & $goal &
          "\"></progress> "
      else:
        bar = "<span class=\"slot\"></span>"
    if row.won:
      inc cleared
    if counting and row.won:
      inc streak
    else:
      counting = false
    let style =
      if row.won: "won"
      elif row.played: "lost"
      else: "idle"
    var link = ""
    if row.replay.len > 0:
      link = "<a href=\"index.html?replay=replays/" & row.replay &
        "\" target=\"_blank\" rel=\"noopener\">replay</a>"
    bar = bar.replace("<progress ", "<progress aria-label=\"" &
      sector.title & " progress\" ")
    rows.add "<tr>" & sectorCells & "<td class=\"" &
      style & "\"><div class=\"status\">" & row.outcome & "</div>" &
      bar & "</td><td class=\"num\">" & row.best &
      "</td><td class=\"num\">" & row.tries.insertSep(',') &
      "</td><td class=\"num\">" & row.gathered.insertSep(',') &
      "</td><td class=\"num\">" & row.lost.insertSep(',') &
      "</td><td>" & link & "</td></tr>\n"
  var
    reload = ""
    progress = """<p class="activity">No games are currently playing or
queued.</p>"""
  if playing + queued > 0:
    reload = "<meta http-equiv=\"refresh\" content=\"10\">\n"
    progress = "<p class=\"activity\">" & $playing & " playing, " &
      $queued & " queued. Updated every ten seconds.</p>" & """
<div class="scroll" role="region" aria-label="Games in progress" tabindex="0">
<table class="live-table">
<caption>Current games. Times are game time; queued games have not started.</caption>
<colgroup><col class="order"><col class="sector"><col class="result">
<col class="elapsed"><col class="limit"></colgroup>
<thead><tr><th scope="col">#</th><th scope="col">Sector</th>
<th scope="col">Progress</th><th scope="col" class="num">Game time</th>
<th scope="col" class="num">Time limit</th></tr></thead>
<tbody>
""" & playingRows & queuedRows & """</tbody>
</table>
</div>
"""
  if plannerProgress.len > 0:
    if playing + queued == 0:
      progress = plannerProgress
    else:
      progress.add plannerProgress
  let text = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
""" & reload & """<title>Campaign results</title>
<style>
""" & CampaignCss & """
</style>
</head>
<body>
<main>
<div class="introduction">
<header>
<p class="eyebrow">Mindustry / Serpulo</p>
<h1>Campaign results</h1>
<p class="summary">""" & summaryLabel & "<strong>" & $cleared & " of " & $shown &
    "</strong> sectors cleared; " & $streak & " in a row.</p>" & """
</header>
<aside aria-label="Reading the results">
<p><em>Best</em> is the fastest capture in game time, using the sector's
saved script. <em>Attempts</em> counts every game played.</p>
<p><em>Result</em>, <em>gathered</em> and <em>lost</em> describe the latest
completed run.
The replay shows the best run, when available.</p>
</aside>
</div>
<section aria-labelledby="progress-heading">
<h2 id="progress-heading">In progress</h2>
""" & progress & """
</section>
""" & plannerSection & """
<section aria-labelledby="records-heading">
<h2 id="records-heading">""" & recordsHeading & """</h2>
<div class="scroll" role="region" aria-label="Sector results" tabindex="0">
<table class="records-table">
<caption>Sector records, in campaign order.</caption>
<colgroup><col class="order"><col class="sector"><col class="result">
<col class="best"><col class="attempts"><col class="gathered">
<col class="lost"><col class="replay"></colgroup>
<thead><tr><th scope="col">#</th><th scope="col">Sector</th>
<th scope="col">Result</th><th scope="col" class="num">Best</th>
<th scope="col" class="num">Attempts</th>
<th scope="col" class="num">Gathered</th>
<th scope="col" class="num">Lost</th><th scope="col">Replay</th></tr></thead>
<tbody>
""" & rows & """</tbody>
</table>
</div>
</section>
</main>
</body>
</html>
"""
  writeFile(path, text)

proc writeTable(path: string, results: JsonNode) =
  ## Writes the campaign table: one row a sector, in campaign order.
  var
    streak = 0
    counting = true
    rows: seq[string]
  for i, sector in Sectors:
    let row = rowFor(sector, results)
    var replay = ""
    if row.replay.len > 0:
      replay = "[replay](" & ViewerUrl & row.replay & ")"
    if counting and row.won:
      inc streak
    else:
      counting = false
    rows.add "| " & $(i + 1) & " | " & sector.title & " | " & sector.goal &
      " | " & row.outcome & " | " & row.best & " | " & row.tries & " | " &
      row.gathered & " | " & row.lost & " | " & replay & " |"
  var text = "# Campaign\n\n"
  text.add "The serpulo campaign in order, one BASIC script a sector " &
    "(drills/levels/NN_sector.bas, the script that set the sector's best " &
    "time; drills/brain.bas for a sector not yet cleared). Run " &
    "tools/mcampaign.nim to play on from the first sector not cleared " &
    "(one attempt by default; --attempts=N plays more). Best is the " &
    "fastest capture ever in game time, attempts counts every game played " &
    "on the sector. Gathered counts items delivered to the core, lost " &
    "counts our buildings destroyed, both from the latest run.\n\n"
  text.add "Score: " & $streak & " of " & $Sectors.len &
    " sectors cleared in a row.\n\n"
  text.add "| # | Sector | Goal | Result | Best | Attempts | Gathered | " &
    "Lost | Replay |\n"
  text.add "|---|---|---|---|---|---|---|---|---|\n"
  text.add rows.join("\n") & "\n\n"
  text.add "Replays open in the coworld-mindustry viewer " &
    "(mindustry-viewer on port 8769).\n"
  writeFile(path, text)

proc main() =
  ## Plays the chosen sectors in order and updates the table.
  let
    root = currentSourcePath().parentDir.parentDir
    engine = getEnv("MINDUSTRY_HOME",
      root.parentDir.parentDir.parentDir / "coworld-mindustry")
    runner = engine / "tmp/mindustry/mindustry"
    viewer = engine / "tmp/mindustry/viewer/replays"
    work = root / "tmp/campaign"
    jsonPath = root / "campaign.json"
  var
    first = 0
    last = Sectors.len
    botPath = ""
    attackBot = ""
    uncleared = false
    forever = false
    sectorBots = initTable[string, string]()
    only = ""
    all = false
    ticks = 432000
    tries = 1
    parallel = 8
    collect = false
    fresh = false
    renderOnly = false
  for arg in commandLineParams():
    if arg.startsWith("--from="):
      first = arg[7 .. ^1].parseInt - 1
    elif arg.startsWith("--to="):
      last = arg[5 .. ^1].parseInt
    elif arg.startsWith("--only="):
      only = arg[7 .. ^1]
    elif arg == "--all":
      all = true
    elif arg.startsWith("--ticks="):
      ticks = arg[8 .. ^1].parseInt
    elif arg.startsWith("--attempts="):
      tries = arg[11 .. ^1].parseInt
    elif arg.startsWith("--parallel="):
      parallel = arg[11 .. ^1].parseInt
    elif arg == "--collect":
      collect = true
    elif arg == "--render-only":
      renderOnly = true
    elif arg == "--fresh":
      fresh = true
    elif arg.startsWith("--bot="):
      botPath = absolutePath(arg[6 .. ^1])
    elif arg.startsWith("--attack-bot="):
      attackBot = absolutePath(arg[13 .. ^1])
    elif arg == "--uncleared":
      uncleared = true
    elif arg == "--forever":
      forever = true
    elif arg.startsWith("--bot-for="):
      let pair = arg[10 .. ^1].split('=', 1)
      if pair.len != 2:
        fail("--bot-for wants sector=path: " & arg)
      sectorBots[pair[0]] = absolutePath(pair[1])
    else:
      fail("unknown argument: " & arg)
  var results =
    if fileExists(jsonPath): parseFile(jsonPath) else: newJObject()
  if renderOnly:
    writeHtml(
      viewer.parentDir / "campaign.html",
      results,
      initTable[string, Live](),
      ticks,
      last
    )
    return
  if not fileExists(runner):
    fail("build the runner first: " & runner)
  createDir(work)
  createDir(viewer)
  proc levelScript(i: int): string =
    ## The saved script of a sector (the one that set its best time).
    root / "drills/levels" / (align($(i + 1), 2, '0') & "_" &
      Sectors[i].name & ".bas")

  proc scriptFor(i: int): string =
    ## The script a sector plays: --bot, else its saved script, else the
    ## drill bot.
    if sectorBots.hasKey(Sectors[i].name):
      sectorBots[Sectors[i].name]
    elif attackBot.len > 0 and Sectors[i].capture == 0:
      attackBot
    elif botPath.len > 0:
      botPath
    elif fileExists(levelScript(i)):
      levelScript(i)
    else:
      root / "drills/brain.bas"

  var chosen: seq[int]
  for i, sector in Sectors:
    if i < first or i >= last or
      (only.len > 0 and sector.name notin only.split(',')):
      continue
    chosen.add i

  proc logName(sector: Sector, attempt: int): string =
    ## The log and replay name of one attempt.
    "campaign_" & sector.name & "_" & $(attempt + 1)

  proc seedOf(i, attempt: int): int =
    ## A new seed for every game played on a sector: 2026 plus the games
    ## played on it before.
    var before = 0
    if results.hasKey(Sectors[i].name):
      let entry = results[Sectors[i].name]
      before = entry{"tries"}.getInt(entry["attempts"].len)
    2026 + before + attempt

  proc command(i, attempt: int): string =
    ## The shell command for one attempt, with its own seed and log.
    let
      sector = Sectors[i]
      name = logName(sector, attempt)
    "cd " & quoteShell(engine) & " && " & quoteShell(runner) &
      " --sector " & sector.name & " --bot " & quoteShell(scriptFor(i)) &
      ":1 --ticks " & $ticks & " --seed " & $seedOf(i, attempt) &
      " --record " & quoteShell(work / name & ".replay") & " > " &
      quoteShell(work / name & ".log") & " 2>&1"

  proc progressOf(name: string): Live =
    ## A running game's last reported tick and wave.
    result.playing = true
    if not fileExists(work / name & ".log"):
      return
    for line in readFile(work / name & ".log").splitLines():
      if line.startsWith("progress "):
        for field in line.splitWhitespace():
          let parts = field.split('=')
          if parts.len == 2 and parts[0] == "tick":
            result.tick = parts[1].parseInt
          if parts.len == 2 and parts[0] == "wave":
            result.wave = parts[1].parseInt

  let started = epochTime()

  proc collectSector(i: int): bool =
    ## Reads a finished sector's attempts into the results and tables, and
    ## links their replays into the viewer. Tells whether one captured it.
    let sector = Sectors[i]
    echo "== ", i + 1, " ", sector.title
    var attempts = newJArray()
    for attempt in 0 ..< tries:
      let name = logName(sector, attempt)
      var row = %*{"seed": seedOf(i, attempt), "replay": name & ".replay",
        "script": scriptFor(i).relativePath(root)}
      if fileExists(work / name & ".log"):
        for line in readFile(work / name & ".log").splitLines():
          if line.startsWith("plan:") and attempt == 0:
            echo "  ", line
          if line.startsWith("Seat ") and "BASIC" in line:
            # The script stopped on an error: the rest is a bot doing nothing.
            row["error"] = %line
          if line.startsWith("cores "):
            # The bot's progress in an attack sector: "cores D of T".
            let parts = line.splitWhitespace()
            if parts.len == 4:
              row["cores"] = %parts[1].parseInt
              row["coresAll"] = %parts[3].parseInt
          if line.startsWith("sector="):
            for field in line.splitWhitespace():
              let parts = field.split('=')
              case parts[0]
              of "outcome":
                row["outcome"] = %parts[1]
              of "ticks", "wave", "gathered", "lost":
                row[parts[0]] = %parts[1].parseInt
              else:
                discard
      if not row.hasKey("outcome"):
        # A game stopped before its end has no result: leave the row out.
        echo "  attempt ", attempt + 1, ": no result in ", name, ".log"
        continue
      if fileExists(work / name & ".replay"):
        # A hard link puts the replay in the viewer without a second copy.
        let target = viewer / name & ".replay"
        removeFile(target)
        try:
          createHardlink(work / name & ".replay", target)
        except OSError:
          copyFile(work / name & ".replay", target)
      else:
        row["replay"] = %""
      attempts.add row
      echo "  attempt ", attempt + 1, ": ", row["outcome"].getStr, " at ",
        clock(row["ticks"].getInt), ", wave ", row["wave"].getInt,
        ", gathered ", row["gathered"].getInt, ", lost ", row["lost"].getInt
      if row.hasKey("error"):
        echo "  script error: ", row["error"].getStr
    if attempts.len == 0:
      return false
    # The record carries over: attempts over all runs (a game already
    # counted, read again by --collect, counts once) and the fastest
    # capture ever, whose script is saved as the sector's script and whose
    # replay stays in the viewer as best_<sector>.replay.
    var
      previous = newJObject()
      total = 0
    if results.hasKey(sector.name):
      previous = results[sector.name]
      total = previous{"tries"}.getInt(previous["attempts"].len)
    var record = previous{"best"}
    for row in attempts:
      var again = false
      for old in previous{"attempts"}.getElems:
        if old{"ticks"} == row["ticks"] and old{"outcome"} == row["outcome"] and
          old{"gathered"} == row{"gathered"}:
            again = true
            row["seed"] = old{"seed"}
      if not again:
        inc total
      if row["outcome"].getStr == "captured" and (record == nil or
        row["ticks"].getInt < record["ticks"].getInt):
          let script = root / row["script"].getStr
          if script != levelScript(i) and fileExists(script):
            createDir(levelScript(i).parentDir)
            copyFile(script, levelScript(i))
          var replay = ""
          if row["replay"].getStr.len > 0:
            replay = "best_" & sector.name & ".replay"
            removeFile(viewer / replay)
            try:
              createHardlink(viewer / row["replay"].getStr, viewer / replay)
            except OSError:
              copyFile(viewer / row["replay"].getStr, viewer / replay)
          record = %*{"ticks": row["ticks"], "seed": row["seed"],
            "script": levelScript(i).relativePath(root), "replay": replay,
            "from": row["script"], "played": now().format("yyyy-MM-dd HH:mm")}
          echo "  new best: ", clock(row["ticks"].getInt), ", script saved as ",
            levelScript(i).relativePath(root)
    results[sector.name] = %*{"attempts": attempts, "tries": total,
      "played": now().format("yyyy-MM-dd HH:mm")}
    if record != nil:
      results[sector.name]["best"] = record
    writeFile(jsonPath, results.pretty & "\n")
    writeTable(root / "campaign.md", results)
    echo "  ", int(epochTime() - started), " s"
    best(attempts)["outcome"].getStr == "captured"

  let page = viewer.parentDir / "campaign.html"
  var live = initTable[string, Live]()
  if all and not collect:
    # Every chosen sector without a result plays, a few games at a time
    # (--fresh plays them all again). A game still running from an earlier
    # run (its log written in the last minute) is watched, not restarted.
    # Every five seconds the page shows each game's progress; a sector whose
    # games are all done goes into the tables with its replay.
    var
      queue: seq[(int, int)]
      running: seq[(int, int, Process)]
    for i in chosen:
      let name = Sectors[i].name
      if results.hasKey(name) and not fresh and
        not (uncleared and not results[name].hasKey("best")):
          continue
      live[Sectors[i].name] = Live()
      for attempt in 0 ..< tries:
        let log = work / logName(Sectors[i], attempt) & ".log"
        var adopted = false
        if fileExists(log) and not fresh and
          epochTime() - getLastModificationTime(log).toUnixFloat < 60 and
          not readFile(log).contains("sector="):
            adopted = true
        if adopted:
          running.add (i, attempt, Process(nil))
          live[Sectors[i].name] = Live(playing: true)
        else:
          queue.add (i, attempt)
    writeHtml(page, results, live, ticks, last)
    while queue.len > 0 or running.len > 0:
      while running.len < parallel and queue.len > 0:
        let (i, attempt) = queue[0]
        queue.delete(0)
        running.add (i, attempt, startProcess(command(i, attempt),
          options = {poEvalCommand}))
        live[Sectors[i].name] = Live(playing: true)
      sleep(5000)
      var still: seq[(int, int, Process)]
      for game in running:
        if game[2] == nil:
          # An adopted game is done once its log has a result, or has gone
          # quiet for five minutes.
          let log = work / logName(Sectors[game[0]], game[1]) & ".log"
          if fileExists(log) and not readFile(log).contains("sector=") and
            epochTime() - getLastModificationTime(log).toUnixFloat < 300:
              still.add game
        elif game[2].peekExitCode() == -1:
          still.add game
        else:
          game[2].close()
      running = still
      for i in chosen:
        let sector = Sectors[i]
        if not live.hasKey(sector.name):
          continue
        var waiting, playing = false
        for game in queue:
          if game[0] == i:
            waiting = true
        for game in running:
          if game[0] == i:
            playing = true
        if playing:
          live[sector.name] = progressOf(logName(sector, 0))
        elif not waiting:
          live.del(sector.name)
          discard collectSector(i)
          # With --forever a sector not cleared yet plays again at once (a
          # new seed), so the games never thin out while a slow one runs.
          if forever and not results[sector.name].hasKey("best"):
            for attempt in 0 ..< tries:
              queue.add (i, attempt)
            live[sector.name] = Live()
      writeHtml(page, results, live, ticks, last)
  else:
    for i in chosen:
      # In order, a sector already cleared is passed over (--fresh or
      # --only plays it again): the campaign goes on from the first one not
      # cleared, and stops there until it falls.
      if not collect and not fresh and only.len == 0 and
        results.hasKey(Sectors[i].name) and
        results[Sectors[i].name].hasKey("best"):
          continue
      if not collect:
        var games: seq[string]
        for attempt in 0 ..< tries:
          games.add command(i, attempt)
        discard execProcesses(games, options = {poEvalCommand}, n = tries)
      let captured = collectSector(i)
      writeHtml(page, results, live, ticks, last)
      if not captured and not all and not collect:
        break
  writeTable(root / "campaign.md", results)
  writeHtml(page, results, live, ticks, last)

main()
