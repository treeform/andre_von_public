## Shared Who Cried Wolf episode fetching for the tools: episode metadata
## from the coworld CLI and replays from public S3, both cached under
## games/who-cried-wolf/eps/cache, plus id expansion for experience
## requests, league rounds, and policy filters.

import std/[httpclient, json, os, osproc, strutils]

const
  CacheDir* = "games/who-cried-wolf/eps/cache"
  League* = "league_a10c10a8-46da-4f0f-bff6-4087c8dac619"

type
  Seat* = object
    label*: string
    role*: string
    faction*: string
    score*: float
    metrics*: JsonNode

proc cli(): string =
  ## Returns the coworld CLI command from the stable metta worktree.
  "uvx --from " &
    quoteShell(getHomeDir() / "p/metta-coworld-cli/packages/coworld[auth]") &
    " coworld"

proc runJson*(arguments: string): JsonNode =
  ## Runs a coworld CLI command with --json and parses its output.
  let (output, code) = execCmdEx(cli() & " " & arguments & " --json",
    options = {poUsePath, poEvalCommand})
  let start = output.find({'{', '['})
  if code != 0 or start < 0:
    quit("coworld " & arguments & " failed:\n" & output, 1)
  parseJson(output[start .. ^1])

proc entries*(node: JsonNode): seq[JsonNode] =
  ## Returns list entries from a CLI listing.
  let list = if node.kind == JArray: node else: node{"entries"}
  if list != nil:
    for item in list:
      result.add item

proc episode*(id: string): JsonNode =
  ## Returns one episode request's metadata, cached once completed.
  createDir(CacheDir)
  let path = CacheDir / id & ".json"
  if fileExists(path):
    return parseFile(path)
  result = runJson("episodes " & id)
  if result{"status"}.getStr() == "completed":
    writeFile(path, $result)

proc replay*(id, url: string): JsonNode =
  ## Returns one replay, cached on disk.
  let path = CacheDir / id & ".replay"
  if not fileExists(path):
    let client = newHttpClient(timeout = 120_000)
    defer:
      client.close()
    writeFile(path, client.getContent(url))
  parseFile(path)

proc episodeIds*(arguments: seq[string]): seq[string] =
  ## Expands experience requests, `--rounds N`, and `--policy ref [limit]`
  ## into completed episode ids. Unknown flags are skipped.
  var i = 0
  while i < arguments.len:
    let argument = arguments[i]
    if argument == "--policy":
      let policy = arguments[i + 1]
      var limit = "50"
      i += 2
      if i < arguments.len and arguments[i][0].isDigit:
        limit = arguments[i]
        inc i
      for item in entries(runJson("episodes -p " & policy & " --limit " &
        limit)):
          if item{"status"}.getStr() == "completed":
            result.add item{"id"}.getStr()
      continue
    if argument == "--rounds":
      let limit = arguments[i + 1]
      i += 2
      for round in entries(runJson("rounds -l " & League &
        " --status completed --limit " & limit)):
          for item in entries(runJson("episodes -r " & round{"id"}.getStr())):
            if item{"status"}.getStr() == "completed":
              result.add item{"id"}.getStr()
      continue
    if argument.startsWith("xreq_"):
      for item in entries(runJson("xp-request episodes " & argument)):
        if item{"status"}.getStr() == "completed":
          result.add item{"id"}.getStr()
    elif argument.startsWith("ereq_"):
      result.add argument
    inc i

proc seats*(meta, data: JsonNode): seq[Seat] =
  ## Joins participants, dealt roles, and results by seat.
  result.setLen(9)
  for participant in meta{"participants"}:
    let position = participant{"position"}.getInt()
    if position in 0 ..< 9:
      result[position].label = participant{"label"}.getStr()
  for event in data{"events"}:
    let payload = event{"payload"}
    if payload{"kind"}.getStr() == "roles":
      for row in payload{"roles"}:
        let slot = row{"slot"}.getInt()
        result[slot].role = row{"role"}.getStr()
        result[slot].faction = row{"faction"}.getStr()
  let outcome = data{"result"}
  for slot in 0 ..< 9:
    result[slot].score = outcome{"scores"}[slot].getFloat()
    result[slot].metrics = outcome{"metrics"}[slot]
