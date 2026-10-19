## Collates per-hero replay stats (from gota_stats) into a policy comparison.
##
##   nim r games/gods-of-the-arena/tools/gota_collate.nim <rows.txt> <rewards.txt...>
##
## rows.txt lines:    "<episode8> row <position> key=value ..."
## rewards.txt lines: "<episode8> <position> <policy:vN> <reward>"
## Policies are grouped into families (identical files under different
## names): khors, aaron (+coach), relh/richard, Jordan. Every other bot is
## pooled as "rest". Prints a Markdown table, one column per family, with
## the stats split into direct control, indirect and downstream rows.

import std/[os, strutils, strformat, tables, algorithm, sequtils]

proc family(policy: string): string =
  let p = policy.toLowerAscii
  if p.startsWith("khors"): "khors"
  elif p.startsWith("aaron-gota-"): "aaron"
  elif p.startsWith("relh") or p.startsWith("richard"): "relh/richard"
  elif p.startsWith("jordan"): "Jordan"
  else: "rest"

const Families = ["khors", "aaron", "relh/richard", "Jordan", "rest"]
const Classes = ["VanguardKnight", "Ranger", "Arcanist", "DruidWarden", "DemonHunter",
                 "DeathKnight", "Crossbowman", "Lich", "Warlock", "Berserker"]

const Direct = [
  ("attackmoves_pm", "attack-move orders / min alive"),
  ("walks_pm", "walk orders / min alive"),
  ("attacks_pm", "attack-target orders / min alive"),
  ("casts_pm", "ability casts / min alive"),
  ("itemuses_pm", "item uses / min alive"),
  ("target_hero", "share of attack orders at heroes"),
  ("target_creep", "share of attack orders at creeps"),
  ("target_building", "share of attack orders at buildings"),
  ("target_god", "share of attack orders at the god"),
  ("time_enemy_half", "share of alive time in the enemy half"),
  ("time_near_enemy_tower", "share of alive time within 12 tiles of an enemy tower"),
  ("time_near_enemy_god", "share of alive time within 20 tiles of the enemy god"),
  ("time_near_own_god", "share of alive time within 15 tiles of own god"),
  ("tiles_pm", "tiles travelled / min alive"),
  ("hp_mean", "mean health fraction while alive"),
  ("time_below50", "share of alive time below 50% health"),
  ("time_below25", "share of alive time below 25% health"),
  ("lowhp_walks", "walk orders issued below 30% health (retreats)"),
  ("orders_pm", "all orders / min alive"),
  ("dup_share", "share of orders identical to the previous order (spam)"),
  ("dup_pm", "identical repeats / min alive"),
  ("rejected_share", "share of orders the engine rejected"),
  ("rejected_pm", "rejected orders / min alive"),
  ("cpu_pct", "CPU: percent of the instruction allowance used (replay telemetry)")]

const Indirect = [
  ("gold_earned", "gold earned"),
  ("gold_spent", "gold spent"),
  ("gold_end", "gold unspent at the end"),
  ("buy_gear", "equipment bought"),
  ("buy_heal", "heal potions/elixirs bought"),
  ("buy_mana", "mana potions bought"),
  ("buy_portal", "portal scrolls bought"),
  ("buy_poison", "poison bought"),
  ("items_consumed", "consumables used"),
  ("buybacks", "buybacks"),
  ("buyback_gold", "gold spent on buybacks")]

const Downstream = [
  ("score", "score (XP - 200/min, floored)"),
  ("xp", "lifetime XP"),
  ("xp_lasthit", "XP from creep last hits"),
  ("xp_shared", "XP shared from nearby creep deaths"),
  ("xp_herokill", "XP from hero kills"),
  ("xp_building", "XP from buildings"),
  ("kills", "hero kills"),
  ("assists", "assists"),
  ("deaths", "deaths"),
  ("building_kills", "building kills"),
  ("tower_kills", "tower kills"),
  ("barracks_kills", "barracks kills"),
  ("level", "level at the end"),
  ("alive_share", "share of the game alive"),
  ("minutes", "game length (minutes)"),
  ("won", "share of games on the winning team")]

when isMainModule:
  if paramCount() < 2:
    quit("usage: gota_collate <rows.txt> <rewards.txt...>")
  var seatPolicy = initTable[string, string]()
  for i in 2 .. paramCount():
    for line in readFile(paramStr(i)).splitLines:
      let f = line.splitWhitespace
      if f.len >= 4: seatPolicy[f[0] & ":" & f[1]] = f[2]
  var sums = initTable[string, Table[string, float]]()
  var counts = initTable[string, int]()
  var policies = initTable[string, Table[string, int]]()
  var classCounts = initTable[string, array[10, int]]()
  for fam in Families:
    sums[fam] = initTable[string, float]()
    counts[fam] = 0
    policies[fam] = initTable[string, int]()
    classCounts[fam] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  for line in readFile(paramStr(1)).splitLines:
    let f = line.splitWhitespace
    if f.len < 4 or f[1] != "row": continue
    let key = f[0] & ":" & f[2]
    if not seatPolicy.hasKey(key): continue
    let policy = seatPolicy[key]
    let fam = family(policy)
    inc counts[fam]
    policies[fam][policy] = policies[fam].getOrDefault(policy) + 1
    for kv in f[3 .. ^1]:
      if kv.startsWith("class="):
        try:
          let c = parseInt(kv[6 .. ^1])
          if c >= 0 and c < 10: inc classCounts[fam][c]
        except ValueError: discard
    for kv in f[3 .. ^1]:
      let parts = kv.split('=', 1)
      if parts.len != 2: continue
      try:
        sums[fam][parts[0]] = sums[fam].getOrDefault(parts[0]) + parseFloat(parts[1])
      except ValueError: discard

  proc cell(fam, key: string): string =
    if counts[fam] == 0: return "-"
    let v = sums[fam].getOrDefault(key) / counts[fam].float
    if key in ["target_hero", "target_creep", "target_building", "target_god",
               "time_enemy_half", "time_near_enemy_tower", "time_near_enemy_god",
               "time_near_own_god", "hp_mean", "time_below50", "time_below25",
               "alive_share", "won", "dup_share", "rejected_share"]:
      &"{v * 100:.0f}%"
    elif key in ["minutes", "attackmoves_pm", "walks_pm", "attacks_pm", "casts_pm", "itemuses_pm"]:
      &"{v:.1f}"
    else:
      &"{v:.0f}"

  var header = "| stat |"
  var rule = "|---|"
  for fam in Families:
    header.add &" {fam} (n {counts[fam]}) |"
    rule.add "---:|"
  proc section(title: string, rows: openArray[(string, string)]) =
    echo &"\n**{title}**\n"
    echo header
    echo rule
    for (key, label) in rows:
      var line = &"| {label} |"
      for fam in Families: line.add &" {cell(fam, key)} |"
      echo line
  echo "Per hero-game means. Families: khors = our policy; aaron = aaron-gota-micro0922 and its coach (one file); relh/richard = one neural file; rest = every other bot."
  for fam in Families:
    var names: seq[string]
    for p, c in policies[fam]: names.add &"{p} x{c}"
    names.sort
    echo &"- {fam}: {names.join(\", \")}"
  echo "\n**Drafting Phase** (share of the family's games in which it drafted each class)\n"
  echo header
  echo rule
  for c in 0 ..< 10:
    var line = &"| {Classes[c]} |"
    for fam in Families:
      if counts[fam] == 0: line.add " - |"
      else: line.add &" {classCounts[fam][c].float * 100 / counts[fam].float:.0f}% |"
    echo line
  section("Direct control (orders, movement, health discipline)", Direct)
  ## Rejection reasons: one row per reason seen anywhere, as rejections per game.
  var reasons: seq[string]
  for fam in Families:
    for key in sums[fam].keys:
      if key.startsWith("rej_") and key notin reasons: reasons.add key
  reasons.sort
  if reasons.len > 0:
    var rows: seq[(string, string)]
    for key in reasons: rows.add((key, "rejected per game: " & key[4 .. ^1]))
    section("Rejected orders by reason (per game)", rows)
  section("Indirect (economy, purchases, buybacks)", Indirect)
  section("Downstream (rewards)", Downstream)
