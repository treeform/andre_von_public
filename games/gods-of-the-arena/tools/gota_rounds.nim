## Summarizes recent league rounds per player: seats, side and score.
##
##   nim r -d:ssl games/gods-of-the-arena/tools/gota_rounds.nim [rounds]
##
## Reads round ids from the dash league JSON, fetches each round's episodes
## from the observatory (user token from ~/.softmax/credentials.yaml), and
## prints per player: games, share of games on Blue (seats 5-9), mean score
## on Red and on Blue, and the mean summed score of their teammates.

import std/[httpclient, json, os, strutils, strformat, tables, algorithm, sequtils]

const
  Dash = "https://softmaxdash-nginx.tail0f4a29.ts.net/league/gods-of-the-arena.json"
  Api = "https://softmax.com/api/observatory/v2/rounds/"

type
  Tally = object
    games, blue: int
    redScore, blueScore, mateScore: float

proc userToken(): string =
  ## Returns the user (not player) bearer token from the credentials file.
  var inTokens = false
  for line in readFile(getHomeDir() / ".softmax/credentials.yaml").splitLines:
    if line.startsWith("tokens:"):
      inTokens = true
    elif inTokens and "https" in line:
      return line.split(": ")[^1].strip(chars = {'"', ' '})
  quit("no user token in credentials.yaml")

proc main() =
  let
    count = if paramCount() >= 1: parseInt(paramStr(1)) else: 20
    client = newHttpClient(timeout = 60_000)
    league = parseJson(client.getContent(Dash))
  client.headers = newHttpHeaders({"Authorization": "Bearer " & userToken()})
  var tallies: Table[string, Tally]
  var rounds = 0
  for round in league["rounds"]:
    if rounds >= count:
      break
    if round{"status"}.getStr != "completed":
      continue
    inc rounds
    let body = parseJson(client.getContent(Api & round["id"].getStr & "/episodes"))
    for episode in body["entries"]:
      if episode{"status"}.getStr != "completed":
        continue
      var
        names: Table[int, string]
        scores: Table[int, float]
        teamTotal = [0.0, 0.0]
      for p in episode["participants"]:
        names[p["position"].getInt] = p{"player_name"}.getStr
      for s in episode["participant_scores"]:
        let position = s["position"].getInt
        scores[position] = s["score"].getFloat
        teamTotal[position div 5] += s["score"].getFloat
      for position, name in names:
        let
          side = position div 5
          score = scores.getOrDefault(position)
        var t = tallies.getOrDefault(name)
        inc t.games
        if side == 1:
          inc t.blue
          t.blueScore += score
        else:
          t.redScore += score
        t.mateScore += teamTotal[side] - score
        tallies[name] = t
  var names = toSeq(tallies.keys)
  names.sort(proc(a, b: string): int =
    let ta = tallies[a]
    let tb = tallies[b]
    cmp((tb.redScore + tb.blueScore) / tb.games.float,
      (ta.redScore + ta.blueScore) / ta.games.float))
  echo &"{rounds} rounds"
  echo "player                     games  blue%   mean    red   blue  mates"
  for name in names:
    let t = tallies[name]
    let red = t.games - t.blue
    echo &"{name:<26} {t.games:5} {t.blue.float / t.games.float * 100:5.0f}% " &
      &"{(t.redScore + t.blueScore) / t.games.float:6.0f} " &
      &"{(if red > 0: t.redScore / red.float else: 0.0):6.0f} " &
      &"{(if t.blue > 0: t.blueScore / t.blue.float else: 0.0):6.0f} " &
      &"{t.mateScore / t.games.float:6.0f}"

main()
