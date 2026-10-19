## Tallies team head-to-head results from hosted experience requests.
##
##   gota_h2h_score <episodes.json>:<red|blue> [...]
##
## Each argument is a saved `coworld xp-request episodes <id> --json` file
## and the side our policy played. Scores come from the observatory episode
## request (a winning hero scores glory, so a side with any score won).

import std/[httpclient, json, os, strformat, strutils]

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
  if paramCount() < 1:
    quit("usage: gota_h2h_score <episodes.json>:<red|blue> [...]")
  let client = newHttpClient(timeout = 60_000)
  client.headers = newHttpHeaders({"Authorization": "Bearer " & userToken()})
  var wins, draws, losses = 0
  for i in 1 .. paramCount():
    let
      parts = paramStr(i).split(':')
      red = parts[1] == "red"
      data = parseJson(readFile(parts[0]))
    for entry in data["entries"]:
      if entry{"status"}.getStr != "completed":
        continue
      let episode = parseJson(client.getContent(
        "https://softmax.com/api/observatory/v2/episode-requests/" & entry["id"].getStr))
      var redScore, blueScore = 0.0
      for s in episode{"participant_scores"}:
        if s["position"].getInt < 5:
          redScore += s["score"].getFloat
        else:
          blueScore += s["score"].getFloat
      let (ours, theirs) = if red: (redScore, blueScore) else: (blueScore, redScore)
      if ours > 0:
        inc wins
      elif theirs > 0:
        inc losses
      else:
        inc draws
  let total = wins + draws + losses
  echo &"W{wins} D{draws} L{losses} of {total} ({(if total > 0: wins * 100 div total else: 0)}% wins)"

main()
