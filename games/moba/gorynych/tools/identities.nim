import std/[httpclient, json, os, osproc, streams, strutils, uri]

const
  Player = "ply_3d22435e-30a2-4f2a-b037-a5c249583788"
  Server = "https://softmax.com/api/observatory"

type MobaError = object of CatchableError

proc token(): string =
  ## Read the active CLI credential without printing or saving it.
  let process = startProcess(
    "uv",
    args = @["--project", "/Users/me/p/metta", "run", "softmax",
      "get-token", "--server", "https://softmax.com/api"],
    options = {poUsePath}
  )
  result = process.outputStream.readAll.strip
  let status = process.waitForExit
  process.close
  if status != 0 or result.len == 0 or result.contains('\n'):
    raise newException(MobaError, "Unable to read active credential")

proc fetch(client: HttpClient, path: string): JsonNode =
  ## Read an authenticated API response without disclosing credentials.
  let response = client.get(Server & path)
  if response.code != Http200:
    raise newException(MobaError, "Identity API status " & $response.code)
  try:
    result = parseJson(response.body)
  except JsonParsingError:
    raise newException(MobaError, "Invalid identity API JSON")

proc main() =
  ## Verify the active identity and list only its requested policy versions.
  let client = newHttpClient(timeout = 30000)
  defer: client.close
  client.headers = newHttpHeaders({"Authorization": "Bearer " & token()})
  let identity = client.fetch("/whoami")
  if identity{"subject_type"}.getStr != "player" or
    identity{"subject_id"}.getStr != Player:
      raise newException(MobaError, "Active identity is not Andre von Auto")
  echo "Verified active player: Andre von Auto " & Player
  if paramCount() > 0:
    let versions = client.fetch(
      "/stats/policy-versions?name_exact=" & encodeUrl(paramStr(1)) &
      "&player_id=" & Player & "&limit=200"
    )
    var entries = newJArray()
    for entry in versions{"entries"}:
      entries.add(%*{
        "id": entry{"id"}.getStr,
        "name": entry{"name"}.getStr,
        "version": entry{"version"}.getInt,
        "verifiedPlayer": Player
      })
    echo entries.pretty

main()
