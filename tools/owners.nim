import
  std/[algorithm, httpclient, json, os, strutils, tables, tempfiles, times],
  crunchy, zippy/ziparchives

const
  ApiUrl* = "https://softmax.com/api"
  PlayerFileLimit = 100 * 1024 * 1024

type
  OwnerError* = object of CatchableError
  OwnerRequest* = object
    verb*: HttpMethod
    url*: string
    token*: string
    body*: string
  OwnerResponse* = object
    code*: int
    body*: string
  OwnerTransport* = proc(request: OwnerRequest): OwnerResponse {.closure.}
  OwnerClient* = object
    token*: string
    player*: string
    api*: string
    transport*: OwnerTransport

proc parseBody(body: string): JsonNode =
  ## Parses API JSON without accepting malformed response metadata.
  try:
    result = parseJson(body)
  except JsonParsingError as error:
    raise newException(OwnerError, "Invalid API JSON: " & error.msg)

proc send(client: OwnerClient, request: OwnerRequest): OwnerResponse =
  ## Sends one request with a captured credential or the supplied test transport.
  if client.transport != nil:
    return client.transport(request)
  let http = newHttpClient(timeout = 120_000, maxRedirects = 0)
  defer:
    http.close()
  http.headers = newHttpHeaders({"Content-Type": "application/json"})
  if request.token.len > 0:
    http.headers["Authorization"] = "Bearer " & request.token
  else:
    http.headers["Content-Type"] = "application/octet-stream"
  let response = http.request(
    request.url,
    httpMethod = request.verb,
    body = request.body
  )
  OwnerResponse(code: response.code.int, body: response.body)

proc requireSuccess(response: OwnerResponse, operation: string) =
  ## Rejects errors before another upload or completion step can run.
  if response.code notin 200 .. 299:
    raise newException(OwnerError,
      operation & " failed with HTTP " & $response.code & ": " &
      response.body)

proc fileBody*(path: string): string =
  ## Freezes a regular file or bounded directory as the exact uploaded bytes.
  if symlinkExists(path):
    raise newException(OwnerError, "Player file cannot be a symlink")
  if fileExists(path):
    if getFileSize(path) > PlayerFileLimit:
      raise newException(OwnerError, "Player file exceeds 100 MiB")
    result = readFile(path)
  elif dirExists(path):
    var paths: seq[string]
    var size = 0'i64
    for entry in walkDirRec(path, yieldFilter = {
      pcFile, pcLinkToFile, pcLinkToDir
    }):
      if symlinkExists(entry):
        raise newException(OwnerError,
          "Player directory cannot contain symlinks")
      size += getFileSize(entry)
      if size > PlayerFileLimit:
        raise newException(OwnerError, "Player directory exceeds 100 MiB")
      paths.add(entry)
    paths.sort()
    let
      archive = ZipArchive()
      directory = createTempDir("auto-player-package-", "")
      package = directory / "player.zip"
    defer:
      removeDir(directory)
    for entry in paths:
      archive.contents[relativePath(entry, path).replace('\\', '/')] =
        ArchiveEntry(
          kind: ekFile,
          contents: readFile(entry),
          lastModified: fromUnix(315532800)
        )
    archive.writeZipArchive(package)
    result = readFile(package)
  else:
    raise newException(OwnerError, "Player file path does not exist")
  if result.len > PlayerFileLimit:
    raise newException(OwnerError, "Player package exceeds 100 MiB")

proc uploadBody*(client: OwnerClient, name, contents: string): JsonNode =
  ## Binds both upload phases to one explicit player and immutable file hash.
  if client.token.len == 0 or not client.player.startsWith("ply_"):
    raise newException(OwnerError, "Upload requires a user token and player ID")
  %*{
    "name": name,
    "content_hash": sha256(contents).toHex().toLowerAscii(),
    "size_bytes": contents.len,
    "player_id": client.player,
    "attributes": {},
    "tags": {}
  }

proc upload*(client: OwnerClient, name, contents: string): JsonNode =
  ## Uploads bytes and completes ownership with the same captured user token.
  let
    body = $client.uploadBody(name, contents)
    response = client.send(OwnerRequest(
      verb: HttpPost,
      url: client.api & "/observatory/stats/policies/files/upload",
      token: client.token,
      body: body
    ))
  if response.code != 409:
    response.requireSuccess("Policy upload preparation")
    let prepared = parseBody(response.body)
    if prepared.kind != JObject:
      raise newException(OwnerError, "Invalid upload preparation response")
    if prepared.hasKey("upload_url") and
      prepared["upload_url"].kind == JString:
        let uploaded = client.send(OwnerRequest(
          verb: HttpPut,
          url: prepared["upload_url"].getStr(),
          body: contents
        ))
        uploaded.requireSuccess("Player file upload")
    elif not prepared.hasKey("existing_policy_version") or
      prepared["existing_policy_version"].kind != JObject:
        raise newException(OwnerError, "Missing upload destination or version")
  let completed = client.send(OwnerRequest(
    verb: HttpPost,
    url: client.api & "/observatory/stats/policies/files/complete",
    token: client.token,
    body: body
  ))
  completed.requireSuccess("Policy completion")
  result = parseBody(completed.body)
  if result.kind != JObject or not result.hasKey("name") or
    result["name"].kind != JString or result["name"].getStr() != name or
    not result.hasKey("version") or
    result["version"].kind != JInt or result["version"].getInt() < 1:
      raise newException(OwnerError, "Invalid completed policy version")
