## Builds experience-request bodies that replay live league rosters.
##
##   nim r -d:ssl games/gods-of-the-arena/tools/gota_live.nim khors:v230 \
##     --coworld cow_... --rounds 945-956 [--episodes 2] [--out eps/bodies_l]
##     [--draft-mode unique|team|open]
##
## Every completed game of those rounds in which our player took a seat
## becomes one body: the same ten policies in the same seats, with the
## candidate in our seat. Games holding a policy that cannot load in
## experience requests (neural zip packages) are skipped. Bodies are named
## <tag>_<round>_<game>.json so two candidates share roster names and pair.

import std/[httpclient, json, os, strutils, strformat]

const
  Dash = "https://softmaxdash-nginx.tail0f4a29.ts.net/league/gods-of-the-arena.json"
  Api = "https://softmax.com/api/observatory/v2/rounds/"
  Player = "Andre von Auto"
  Unloadable = ["khors_neural"]

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
    quit("usage: gota_live.nim <candidate name:vN> --coworld cow_... --rounds A-B [--episodes N] [--out dir]")
  let candidate = paramStr(1)
  var
    coworld = ""
    first = 0
    last = 0
    episodes = 2
    draftMode = ""
    dir = "games/gods-of-the-arena/eps/bodies_l"
    i = 2
  while i <= paramCount():
    case paramStr(i)
    of "--coworld":
      coworld = paramStr(i + 1)
    of "--rounds":
      let parts = paramStr(i + 1).split('-')
      first = parseInt(parts[0])
      last = parseInt(parts[^1])
    of "--episodes":
      episodes = parseInt(paramStr(i + 1))
    of "--draft-mode":
      draftMode = paramStr(i + 1)
    of "--out":
      dir = paramStr(i + 1)
    else:
      quit("unknown option " & paramStr(i))
    i += 2
  doAssert coworld.len > 0, "pass --coworld cow_..."
  doAssert first > 0 and last >= first, "pass --rounds A-B"
  createDir(dir)
  let
    client = newHttpClient(timeout = 60_000)
    league = parseJson(client.getContent(Dash))
    stem = candidate.replace(":", "_")
  client.headers = newHttpHeaders({"Authorization": "Bearer " & userToken()})
  var
    written = 0
    skipped = 0
  for round in league["rounds"]:
    let number = round["number"].getInt
    if number < first or number > last or round{"status"}.getStr != "completed":
      continue
    let body = parseJson(client.getContent(Api & round["id"].getStr & "/episodes"))
    var game = 0
    for episode in body["entries"]:
      inc game
      if episode{"status"}.getStr != "completed":
        continue
      var
        roster = newJArray()
        ours = -1
        loadable = true
      for p in episode["participants"]:
        let name = p["policy_name"].getStr
        if name in Unloadable:
          loadable = false
        var policyRef = &"{name}:v{p[\"version\"].getInt}"
        if p{"player_name"}.getStr == Player:
          ours = p["position"].getInt
          policyRef = candidate
        roster.add %*{"slot": p["position"].getInt,
          "player": {"policy_ref": policyRef}}
      if ours < 0:
        continue
      if not loadable or roster.len != 10:
        inc skipped
        continue
      let path = dir / &"{stem}_{number}_{game:02}.json"
      var body = %*{"coworld_id": coworld,
        "num_episodes": episodes,
        "notes": &"{candidate} live roster round {number} game {game} seat {ours}",
        "roster": roster}
      if draftMode.len > 0:
        body["game_config_overrides"] = %*{"draft_mode": draftMode}
      writeFile(path, pretty(body))
      inc written
  echo &"{written} bodies in {dir}, {skipped} games skipped (unloadable policy)"

main()
