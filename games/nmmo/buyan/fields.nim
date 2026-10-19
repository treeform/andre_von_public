import std/[algorithm, json, os, strutils]

const
  PlayerId = "ply_3d22435e-30a2-4f2a-b037-a5c249583788"
  LeagueId = "league_d7e141f9-ee29-4a46-b15c-5bbdb1639a44"

type BuyanError = object of CatchableError

proc save(path: string, data: JsonNode) =
  ## Preserve each registered request exactly across retries.
  let content = pretty(data)
  if fileExists(path) and readFile(path) != content:
    raise newException(BuyanError, "Refusing to change " & path)
  writeFile(path, content)

proc main() =
  ## Freeze the current top three other players and separate own versions.
  try:
    let
      root = currentSourcePath().parentDir()
      directory = root / "top3"
      snapshot = parseJson(readFile(root / "league_current.json"))
    var
      ranked: seq[JsonNode]
      labels: seq[string]
      field = newJArray()
    for player in snapshot["ratings"]:
      if player["playerId"].getStr() != PlayerId:
        ranked.add(player)
    ranked.sort(proc(a, b: JsonNode): int =
      cmp(a["rank"].getInt(), b["rank"].getInt()))
    if ranked.len < 3:
      raise newException(BuyanError, "Fewer than three other players.")
    for index in 0 ..< 3:
      let name = ranked[index]["player"].getStr()
      var selected: seq[JsonNode]
      for standing in snapshot["standings"]:
        if standing["player"].getStr() == name and
          standing["champion"].getBool() and
          standing["substatus"].getStr() == "active":
            selected.add(standing)
      if selected.len != 1:
        raise newException(BuyanError, "Expected one live policy: " & name)
      let label = selected[0]["policy"].getStr() & ":v" &
        $selected[0]["version"].getInt()
      labels.add(label)
      field.add(%*{
        "player": name, "player_id": ranked[index]["playerId"],
        "policy_ref": label, "rating": ranked[index]["value"],
        "seats": 2
      })
    createDir(directory)
    save(directory / "field.json", %*{
      "source": "softmax-hosted-xp", "league_id": LeagueId,
      "player_id": PlayerId, "opponents": field,
      "rule": "One own version per request; no own-version matchups."
    })
    for version in 1 .. 6:
      let label = "buyan:v" & $version
      for batch in ["a", "b"]:
        var roster = newJArray()
        for seat in 0 ..< 2:
          roster.add(%*{"slot": -1, "player": {"policy_ref": label}})
        for opponent in labels:
          for seat in 0 ..< 2:
            roster.add(%*{
              "slot": -1, "player": {"policy_ref": opponent}
            })
        let request = %*{
          "idempotency_key": "buyan-20260912-top3-separate-v" &
            $version & "-" & batch,
          "target": {"league_id": LeagueId}, "num_episodes": 15,
          "roster": roster,
          "notes": label & " versus frozen current top3 unique others: " &
            labels.join(", ") & ". One own version only. Two seats per " &
            "policy in eight-seat game. Independent champion/candidate " &
            "requests share this exact field. First cohort30 episodes; " &
            "hosted activation and dashboard significance required."
        }
        save(directory / ("request_v" & $version & "_" & batch &
          ".json"), request)
    echo "Frozen field: ", labels.join(", ")
    echo "12 requests registered, 30 episodes per buyan version1..6."
  except BuyanError:
    raise
  except CatchableError as error:
    raise newException(BuyanError, "Cannot freeze field: " & error.msg)

main()
