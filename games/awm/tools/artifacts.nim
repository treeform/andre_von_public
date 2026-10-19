import
  std/[json, os, strutils, uri],
  curly, zippy,
  replays

const
  PublicHost = "softmax-public.s3.amazonaws.com"
  TimeoutSeconds = 30

type
  AwmError = object of CatchableError
  Artifact = object
    id, job, url: string

proc readText(path: string): string =
  ## Reads a saved response with a library-specific boundary error.
  try:
    result = readFile(path)
  except IOError as error:
    raise newException(AwmError, "Cannot read " & path & ": " & error.msg)

proc textField(node: JsonNode, field: string): string =
  ## Requires a textual metadata field without silently coercing it.
  if node.kind != JObject or not node.hasKey(field):
    raise newException(AwmError, "XP metadata lacks field " & field)
  if node[field].kind == JNull:
    return ""
  if node[field].kind != JString:
    raise newException(AwmError, "XP field is not text: " & field)
  node[field].getStr

proc validId(value: string): bool =
  ## Accepts UUID filenames without allowing path separators or traversal.
  if value.len != 36:
    return false
  for i, character in value:
    if i in [8, 13, 18, 23]:
      if character != '-':
        return false
    elif character notin {'0' .. '9', 'a' .. 'f', 'A' .. 'F'}:
      return false
  true

proc readArtifacts(path: string): tuple[request: string, files: seq[Artifact]] =
  ## Selects completed episodes with explicit public replay URLs.
  var data: JsonNode
  try:
    data = parseJson(readText(path))
  except JsonParsingError as error:
    raise newException(AwmError, "Invalid saved XP JSON: " & error.msg)
  result.request = data.textField("id")
  if not data.hasKey("episodes") or data["episodes"].kind != JArray:
    raise newException(AwmError, "Saved XP JSON lacks episodes")
  for episode in data["episodes"]:
    if episode.textField("status") != "completed":
      continue
    let artifact = Artifact(
      id: episode.textField("id"),
      job: episode.textField("job_id"),
      url: episode.textField("replay_url")
    )
    if artifact.url.len == 0:
      continue
    if not validId(artifact.job):
      raise newException(AwmError, "Completed episode has invalid job UUID")
    let address = parseUri(artifact.url)
    if address.scheme != "https" or address.hostname != PublicHost or
      address.path != "/replays/" & artifact.job & ".replay" or
      address.query.len > 0 or address.anchor.len > 0:
        raise newException(AwmError,
          "Unsupported public replay URL for job " & artifact.job)
    result.files.add artifact

proc validateReplay(body: string) =
  ## Rejects HTTP error bodies and malformed replay payloads before saving.
  if body.len > DefaultMaxReplayBytes:
    raise newException(AwmError, "Downloaded replay exceeds its byte limit")
  var bytes = body
  if bytes.len > 2 and bytes[0] == '\x1f' and bytes[1] == '\x8b':
    try:
      bytes = uncompress(bytes, dfGzip)
    except ZippyError as error:
      raise newException(AwmError, "Replay gzip failed: " & error.msg)
  let data = decodeReplayFile(ReplayGame, ReplayGameVersion, bytes, ReplayData)
  data.validate()

proc fetch(curl: Curly, artifact: Artifact, directory: string): bool =
  ## Fetches and validates one public artifact, preserving valid cached files.
  let path = directory / artifact.job & ".replay"
  if fileExists(path):
    validateReplay(readText(path))
    return false
  var response: Response
  try:
    response = curl.get(artifact.url, timeout = TimeoutSeconds)
  except CatchableError as error:
    raise newException(AwmError,
      "Replay download failed for " & artifact.job & ": " & error.msg)
  if response.code != 200:
    raise newException(AwmError,
      "Replay HTTP " & $response.code & " for job " & artifact.job)
  validateReplay(response.body)
  try:
    writeFile(path & ".partial", response.body)
    moveFile(path & ".partial", path)
  except OSError, IOError:
    raise newException(AwmError,
      "Cannot save replay " & artifact.job & ": " & getCurrentExceptionMsg())
  true

proc parseLimit(value: string): int =
  ## Parses a positive episode cap or the explicit all option.
  if value == "all":
    return high(int)
  try:
    result = parseInt(value)
  except ValueError as error:
    raise newException(AwmError, "Invalid replay limit: " & error.msg)
  if result <= 0:
    raise newException(AwmError, "Replay limit must be positive")

proc main() =
  ## Downloads public replay artifacts only from a saved XP response.
  if paramCount() notin 2 .. 3:
    raise newException(AwmError,
      "Usage: artifacts SAVED_XP_JSON REPLAY_DIRECTORY [10|30|all]")
  let
    source = readArtifacts(paramStr(1))
    directory = paramStr(2)
    limit = if paramCount() == 3: parseLimit(paramStr(3)) else: 10
    count = min(limit, source.files.len)
  try:
    createDir(directory)
  except OSError as error:
    raise newException(AwmError, "Cannot create replay directory: " & error.msg)
  let curl = newCurly(1)
  defer:
    curl.close()
  var downloaded = 0
  echo source.request, ": completed public replays=", source.files.len,
    " selected=", count
  for i in 0 ..< count:
    if curl.fetch(source.files[i], directory):
      inc downloaded
    if (i + 1) mod 10 == 0 or i + 1 == count:
      echo "Validated ", i + 1, "/", count, " artifacts."
  echo "Downloaded=", downloaded, " cached=", count - downloaded,
    " directory=", directory

main()
