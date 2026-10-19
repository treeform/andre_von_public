import std/[json, os, strutils]

type BuyanError = object of CatchableError

proc main() =
  ## Register a solo benchmark: one seat of our policy alone in the world
  ## (only mobs, no other players), to see the score ceiling without
  ## competition. Written to experiments/solo/<label>/request_<batch>.json.
  if paramCount() != 3:
    raise newException(BuyanError, "Expected buyan:vN, count, batch.")
  let
    label = paramStr(1)
    count = parseInt(paramStr(2))
    batch = paramStr(3)
    root = currentSourcePath().parentDir().parentDir()
  if not label.startsWith("buyan:v") or parseInt(label[7 .. ^1]) < 2 or
      count < 1 or batch.len != 1 or batch[0] notin {'a'..'z'}:
    raise newException(BuyanError, "Invalid solo benchmark request.")
  let
    body = parseJson(readFile(root / "top3" / "request_v1_a.json"))
    directory = root / "experiments" / "solo" / label.replace(":", "_")
    destination = directory / ("request_" & batch & ".json")
  createDir(directory)
  body["idempotency_key"] = %("buyan-20260914-octo-" & label & "-" & batch)
  body["num_episodes"] = %count
  # The coworld manifest requires at least two seats (players minItems 2)
  # and the request body may not carry a game_config, so the nearest
  # hosted solo run is two seats of our own policy in a 512x512 world.
  # The league target resolves an eight-seat game config and rejects any
  # other roster size, so the nearest hosted solo run is eight seats of our
  # own policy: no other player's policy in the world.
  var roster = newJArray()
  for seat in 0 ..< 8:
    roster.add(%*{"slot": -1, "player": {"policy_ref": label}})
  body["roster"] = roster
  body["notes"] = %("self-field benchmark: eight seats of " & label &
    " and mobs, no other player's policy in the world (the league game config is fixed at eight seats). " &
    "Hosted episodes only; no league submission implied.")
  let content = pretty(body)
  if fileExists(destination) and readFile(destination) != content:
    raise newException(BuyanError, "Refusing to change registered request.")
  writeFile(destination, content)
  echo destination
main()
