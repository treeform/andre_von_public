import std/[json, os, strutils]

type BuyanError = object of CatchableError

proc main() =
  ## Write one immutable matched-field hosted experiment request.
  if paramCount() != 4:
    raise newException(BuyanError,
      "Expected trial, candidate policy reference, episodes and batch.")
  let
    trial = paramStr(1)
    reference = paramStr(2)
    count = parseInt(paramStr(3))
    batch = paramStr(4)
    directory = currentSourcePath().parentDir()
  if trial notin ["clean", "armor", "hunt", "sword", "escape"]:
    raise newException(BuyanError, "Unknown experiment.")
  if count < 10 or batch.len == 0 or
    batch.find('/') >= 0 or batch.find('\\') >= 0:
      raise newException(BuyanError, "Invalid episode count or batch.")
  let body = parseJson(readFile(directory / "baseline_request.json"))
  body["idempotency_key"] = %(
    "buyan-20260912-" & trial & "-" & batch & "-" & reference
  )
  body["roster"][1]["player"]["policy_ref"] = %reference
  body["num_episodes"] = %count
  body["notes"] = %(
    "Single-change " & trial & " vs submitted buyan:v1. Field A: " &
    "relh-nmmo-consensus:v1, nmmo-opt:v6, daveey-nmmo-nim:v11 x2 each. " &
    "Same episode paired comparison; only issued changed-action trigger " &
    "episodes eligible. Batch " & batch & ". Planned looks10/30/100/300; " &
    "dashboard significance and sign-test p<=0.0025 required."
  )
  let path = directory / "experiments" / trial / ("request_" & batch &
    ".json")
  if fileExists(path):
    if readFile(path) != pretty(body):
      raise newException(BuyanError, "Refusing to overwrite request.")
  else:
    writeFile(path, pretty(body))
  echo path

main()
