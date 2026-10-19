import std/[json, os, strutils]

type BuyanError = object of CatchableError

proc main() =
  ## Register one own version against the frozen three other players.
  if paramCount() != 4:
    raise newException(BuyanError, "Expected trial, buyan:vN, count, batch.")
  let
    trial = paramStr(1)
    label = paramStr(2)
    count = parseInt(paramStr(3))
    batch = paramStr(4)
    root = currentSourcePath().parentDir().parentDir()
  if trial.len == 0 or not trial.allCharsInSet({'a'..'z'}) or
    not label.startsWith("buyan:v") or parseInt(label[7 .. ^1]) < 2 or
    count < 10 or batch notin ["a", "b", "c", "d", "e", "f", "g", "h"]:
      raise newException(BuyanError, "Invalid registered candidate.")
  let
    body = parseJson(readFile(root / "top3" / "request_v1_a.json"))
    directory = root / "experiments" / trial / "top3"
    destination = directory / ("request_" & batch & ".json")
  createDir(directory)
  body["idempotency_key"] = %("buyan-20260912-top3-" & trial & "-" &
    label & "-" & batch)
  body["num_episodes"] = %count
  for seat in 0 ..< 2:
    body["roster"][seat]["player"]["policy_ref"] = %label
  body["notes"] = %(trial & " single strategy: " & label &
    " versus richard-nmmo:v1, nmmo-baseline:v1, relh-nmmo-consensus:v1. " &
    "One own version only. Same frozen field as champion buyan:v1. " &
    "First cohort30; only hosted triggered episodes and dashboard " &
    "significance may support keep. No league submission implied.")
  let content = pretty(body)
  if fileExists(destination) and readFile(destination) != content:
    raise newException(BuyanError, "Refusing to change registered request.")
  writeFile(destination, content)
  echo destination

main()
