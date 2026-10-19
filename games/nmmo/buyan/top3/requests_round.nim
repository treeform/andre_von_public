import std/[json, os, strutils]

type BuyanError = object of CatchableError

const RoundField = [
  "relh-nmmo-consensus:v1", "relh-nmmo-consensus:v1", "richard-nmmo:v1",
  "nmmo-baseline:v1", "nmmo-opt:v6", "daveey-nmmo-nim:v11"]

proc main() =
  ## Register one own version against the league round field: the top 3
  ## (relh twice as the current leader) plus the two other round players.
  ## Rounds seat 8 agents over 6 players; league rounds 2029-2032 gave our
  ## seats 1.5 per game, so we take two. Written to experiments/<trial>/round/.
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
    count < 10 or batch notin ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l"]:
      raise newException(BuyanError, "Invalid registered candidate.")
  let
    body = parseJson(readFile(root / "top3" / "request_v1_a.json"))
    directory = root / "experiments" / trial / "round"
    destination = directory / ("request_" & batch & ".json")
  createDir(directory)
  body["idempotency_key"] = %("buyan-20260913-round-" & trial & "-" & label & "-" & batch)
  body["num_episodes"] = %count
  var roster = newJArray()
  for seat in 0 ..< 2:
    roster.add(%*{"slot": -1, "player": {"policy_ref": label}})
  for other in RoundField:
    roster.add(%*{"slot": -1, "player": {"policy_ref": other}})
  body["roster"] = roster
  body["notes"] = %(trial & " round field: " & label &
    " versus relh-nmmo-consensus:v1 x2, richard-nmmo:v1, nmmo-baseline:v1, " &
    "nmmo-opt:v6, daveey-nmmo-nim:v11 (the league round players). " &
    "Hosted episodes only; no league submission implied.")
  let content = pretty(body)
  if fileExists(destination) and readFile(destination) != content:
    raise newException(BuyanError, "Refusing to change registered request.")
  writeFile(destination, content)
  echo destination

main()
