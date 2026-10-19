## Generates the engine-constants block of a Gods of the Arena BASIC policy
## from the engine's own content.nim, so the policy never drifts from the
## build it plays on. Usage:
##   nim r tools/gota_constants.nim <polyworld checkout> [policy.bas ...]
## Without policy files the block is printed; with them the block between the
## ">>> engine constants" and "<<< engine constants" markers is replaced (or
## inserted after the leading comment block when the markers are missing).

import std/[os, osproc, strutils, tables, strformat]

type
  Entry = object
    label: string
    fields: Table[string, string]
    abilities: seq[string]

const
  BeginMarker = "' >>> engine constants"
  EndMarker = "' <<< engine constants"
  WorldScale = 60000

proc readScalars(text: string): Table[string, int] =
  ## Collects the numeric top-level constants (plain ints and N * TickRate).
  result["TickRate"] = 24
  for line in text.splitLines:
    let stripped = line.strip
    if not stripped.contains("* = ") and not stripped.contains("* ="):
      continue
    let parts = stripped.split("=", 1)
    if parts.len != 2:
      continue
    let name = parts[0].strip.replace("*", "").strip
    var value = parts[1].strip
    if value.endsWith("* TickRate"):
      let factor = value[0 ..< value.len - "* TickRate".len].strip
      if factor.allCharsInSet({'0'..'9', '_'}):
        result[name] = parseInt(factor.replace("_", "")) * result["TickRate"]
      continue
    var digits = value
    if digits.contains("'"):
      digits = digits.split("'")[0]
    if digits.len > 0 and digits.allCharsInSet({'0'..'9', '_'}):
      result[name] = parseInt(digits.replace("_", ""))

proc readArray(text, header: string): seq[Entry] =
  ## Parses one `Name*: array[Index, Type] = [` table into entries.
  let start = text.find(header)
  doAssert start >= 0, "table not found: " & header
  var lines = text[start .. ^1].splitLines
  var i = 1
  var entry: Entry
  var open = false
  var depth = 0
  var body = ""
  while i < lines.len:
    let line = lines[i]
    let stripped = line.strip
    if not open:
      if stripped == "]":
        break
      let paren = stripped.find("(")
      if paren > 0 and stripped.endsWith("("):
        entry = Entry()
        var label = stripped[0 ..< paren]
        if label.contains(":"):
          label = label.split(":")[0].strip
        entry.label = label
        open = true
        depth = 1
        body = ""
      elif stripped.endsWith("(),") or stripped.endsWith("()"):
        result.add Entry(label: "")
    else:
      for c in stripped:
        if c == '(' or c == '[':
          inc depth
        elif c == ')' or c == ']':
          dec depth
      if depth <= 0:
        var text = body
        let abilityStart = text.find("abilities: [")
        if abilityStart >= 0:
          let abilityEnd = text.find("]", abilityStart)
          let inner = text[abilityStart + "abilities: [".len ..< abilityEnd]
          for name in inner.split(","):
            if name.strip.len > 0:
              entry.abilities.add name.strip
          text = text[0 ..< abilityStart] & text[abilityEnd + 1 .. ^1]
        for piece in text.split(","):
          let pair = piece.split(":", 1)
          if pair.len == 2:
            let key = pair[0].strip
            let value = pair[1].strip
            if key.len > 0 and key.allCharsInSet({'a'..'z', 'A'..'Z'}):
              entry.fields[key] = value
        result.add entry
        open = false
      else:
        body.add stripped & " "
    inc i

proc number(entry: Entry, key: string, scalars: Table[string, int]): int =
  ## Reads a numeric field, resolving named constants; missing fields are 0.
  if key notin entry.fields:
    return 0
  let raw = entry.fields[key].replace("_", "")
  if raw.len > 0 and raw.allCharsInSet({'0'..'9'}):
    return parseInt(raw)
  if raw in scalars:
    return scalars[raw]
  0

proc tiles(units: int): string =
  ## Formats a world-unit distance as tiles with four decimals.
  formatFloat(units / WorldScale, ffDecimal, 4)

proc quoted(entry: Entry): string =
  ## Returns the entry's display name without quotes.
  entry.fields.getOrDefault("name", entry.label).replace("\"", "")

proc generate(checkout: string): string =
  ## Builds the BASIC block from the checkout's content.nim.
  let content = readFile(checkout / "examples" / "gods_of_the_arena" / "content.nim")
  let scalars = readScalars(content)
  var commit = "unknown"
  let (output, code) = execCmdEx("git -C " & quoteShell(checkout) & " rev-parse --short HEAD")
  if code == 0:
    commit = output.strip
  let heroes = readArray(content, "HeroSpecs*: array[HeroClass, HeroSpec] = [")
  let abilities = readArray(content, "BaseAbilitySpecs*: array[Ability, AbilitySpec] = [")
  let items = readArray(content, "ItemSpecs*: array[Item, ItemSpec] = [")
  var abilityByName: Table[string, Entry]
  for ability in abilities:
    abilityByName[ability.label] = ability
  var lines: seq[string]
  lines.add &"{BeginMarker}: generated by tools/gota_constants.nim from polyworld {commit} content.nim, do not edit by hand"
  lines.add "' distances are tiles (world units / 60000); ability index is class * 4 + slot (slot 0 is the passive)"
  lines.add "dim engineHeroAttackReach(9)"
  lines.add "dim engineHeroAttackTicks(9)"
  lines.add "dim engineHeroBaseDamage(9)"
  lines.add "dim engineHeroDamagePerLevel(9)"
  lines.add "dim engineHeroBaseHitPoints(9)"
  lines.add "dim engineHeroHitPointsPerLevel(9)"
  lines.add "dim engineHeroMovePerTick(9)"
  lines.add "dim engineAbilityReach(39)"
  lines.add "dim engineAbilityDamage(39)"
  lines.add "dim engineAbilityHeal(39)"
  lines.add "dim engineAbilityManaCost(39)"
  lines.add "dim engineAbilityCooldown(39)"
  lines.add &"dim engineItemCost({items.len - 1})"
  lines.add "if engineConstantsReady = 0 then"
  lines.add "  engineConstantsReady = 1"
  for name in ["TickRate", "InventorySlots", "MeleeCreepsPerBarracks", "MaxItemStack",
      "PotionCooldownTicks", "PortalChannelTicks", "PortalCooldownTicks",
      "SpawnRecoverySeconds", "DraftPickTicks", "HeroClassesPerTeam"]:
    if name in scalars:
      lines.add &"  engine{name} = {scalars[name]}"
  for classIndex, hero in heroes:
    let label = hero.quoted
    lines.add &"  ' {classIndex} {label}"
    lines.add &"  engineHeroAttackReach({classIndex}) = {tiles(hero.number(\"attackRange\", scalars))}"
    lines.add &"  engineHeroAttackTicks({classIndex}) = {hero.number(\"attackTicks\", scalars)}"
    lines.add &"  engineHeroBaseDamage({classIndex}) = {hero.number(\"baseDamage\", scalars)}"
    lines.add &"  engineHeroDamagePerLevel({classIndex}) = {hero.number(\"damagePerLevel\", scalars)}"
    lines.add &"  engineHeroBaseHitPoints({classIndex}) = {hero.number(\"baseHitPoints\", scalars)}"
    lines.add &"  engineHeroHitPointsPerLevel({classIndex}) = {hero.number(\"hitPointsPerLevel\", scalars)}"
    lines.add &"  engineHeroMovePerTick({classIndex}) = {tiles(hero.number(\"baseMovePerTick\", scalars))}"
    for slot, abilityName in hero.abilities:
      doAssert abilityName in abilityByName, "unknown ability " & abilityName
      let ability = abilityByName[abilityName]
      let index = classIndex * 4 + slot
      let kind = ability.fields.getOrDefault("kind", "Strike")
      var reach = ability.number("range", scalars)
      if kind != "Strike":
        reach = 0
      lines.add &"  ' {index} {label} {ability.quoted} ({kind})"
      lines.add &"  engineAbilityReach({index}) = {tiles(reach)}"
      lines.add &"  engineAbilityDamage({index}) = {ability.number(\"damage\", scalars)}"
      lines.add &"  engineAbilityHeal({index}) = {ability.number(\"heal\", scalars)}"
      lines.add &"  engineAbilityManaCost({index}) = {ability.number(\"manaCost\", scalars)}"
      lines.add &"  engineAbilityCooldown({index}) = {ability.number(\"cooldownTicks\", scalars)}"
  for itemIndex, item in items:
    if item.label.len == 0 and item.fields.len == 0:
      continue
    lines.add &"  engineItemCost({itemIndex}) = {item.number(\"cost\", scalars)} ' {item.quoted}"
  lines.add "end if"
  lines.add EndMarker
  lines.join("\n") & "\n"

proc apply(path, blockText: string) =
  ## Replaces or inserts the constants block in one policy file.
  let text = readFile(path)
  let beginAt = text.find(BeginMarker)
  var output: string
  if beginAt >= 0:
    let endAt = text.find(EndMarker, beginAt)
    doAssert endAt >= 0, "end marker missing in " & path
    var after = endAt + EndMarker.len
    if after < text.len and text[after] == '\n':
      inc after
    output = text[0 ..< beginAt] & blockText & text[after .. ^1]
  else:
    var lines = text.splitLines
    var insertAt = 0
    while insertAt < lines.len and lines[insertAt].startsWith("'"):
      inc insertAt
    let blockLines = blockText.strip(chars = {'\n'}).splitLines
    output = (lines[0 ..< insertAt] & blockLines & lines[insertAt .. ^1]).join("\n")
  writeFile(path, output)
  echo "updated ", path

when isMainModule:
  let arguments = commandLineParams()
  doAssert arguments.len >= 1, "usage: gota_constants <polyworld checkout> [policy.bas ...]"
  let blockText = generate(arguments[0])
  if arguments.len == 1:
    stdout.write blockText
  else:
    for path in arguments[1 .. ^1]:
      apply(path, blockText)
