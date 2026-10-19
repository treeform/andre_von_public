import std/[os, strutils]

const
  Submitted = currentSourcePath().parentDir / "../radogost/radogost.bas"
  Candidate = currentSourcePath().parentDir / "../experiments/shields.bas"

proc replaceOnce(source: var string, old, changed: string) =
  ## Refuses ambiguous patches while freezing the isolated candidate.
  doAssert source.count(old) == 1, "Expected one source block: " & old
  source = source.replace(old, changed)

proc main() =
  ## Adds exact fragile-army protection value to the existing Shields model.
  var source = readFile(Submitted)
  source.replaceOnce(
    "rootHealth = 0\nownSize = 0",
    "rootHealth = 0\nrootFragilePower = 0\nownSize = 0"
  )
  source.replaceOnce(
    "    rootHealth = rootHealth + selfBoardHp(i)",
    "    rootHealth = rootHealth + selfBoardHp(i)\n" &
      "    IF selfBoardHp(i) = 1 THEN rootFragilePower = " &
        "rootFragilePower + selfBoardPower(i)"
  )
  source.replaceOnce(
    "  stateHealth = rootHealth",
    "  stateHealth = rootHealth\n  stateFragilePower = rootFragilePower"
  )
  source.replaceOnce(
    "      priority = stateCount * .4",
    "      priority = stateCount * .4 + stateFragilePower * 2"
  )
  source.replaceOnce(
    "  CASE 5\n    stateHealth = stateHealth + stateCount",
    "  CASE 5\n    stateHealth = stateHealth + stateCount\n" &
      "    utility = utility + stateFragilePower * 2.5\n" &
      "    stateFragilePower = 0"
  )
  writeFile(Candidate, source)

main()
