import std/[httpcore, json, os, strutils, tempfiles], owners

const
  Player = "ply_3d22435e-30a2-4f2a-b037-a5c249583788"
  Token = "user-test-token"
  Bytes = "end\n"

proc client(transport: OwnerTransport): OwnerClient =
  ## Creates a fixed upload identity without reading machine credentials.
  OwnerClient(token: Token, player: Player, api: ApiUrl,
    transport: transport)

echo "Testing immutable identity across upload and completion"
block:
  var requests: seq[OwnerRequest]
  var selectedPlayer = Player
  let transport: OwnerTransport = proc(request: OwnerRequest): OwnerResponse =
    requests.add(request)
    case requests.len
    of 1:
      selectedPlayer = "ply-other-player"
      OwnerResponse(code: 200,
        body: "{\"upload_url\":\"https://storage.example/upload\"}")
    of 2:
      OwnerResponse(code: 200)
    else:
      OwnerResponse(code: 200,
        body: "{\"name\":\"radogost\",\"version\":9,\"id\":\"test-id\"}")
  let result = client(transport).upload("radogost", Bytes)
  doAssert result["version"].getInt() == 9
  doAssert selectedPlayer != Player
  doAssert requests.len == 3
  doAssert requests[0].verb == HttpPost
  doAssert requests[0].url.endsWith("/files/upload")
  doAssert requests[2].url.endsWith("/files/complete")
  doAssert requests[0].token == Token and requests[2].token == Token
  doAssert requests[0].body == requests[2].body
  let body = parseJson(requests[0].body)
  doAssert body["player_id"].getStr() == Player
  doAssert body["content_hash"].getStr() ==
    "48332fe667bc51ac4a51ba0efe734441c90def55c60a26d7db275ecbbcf42f15"
  doAssert body["size_bytes"].getInt() == Bytes.len
  doAssert requests[1].verb == HttpPut
  doAssert requests[1].token == ""
  doAssert requests[1].body == Bytes

echo "Testing already stored bytes still complete for the explicit player"
block:
  var requests: seq[OwnerRequest]
  let transport: OwnerTransport = proc(request: OwnerRequest): OwnerResponse =
    requests.add(request)
    if requests.len == 1:
      OwnerResponse(code: 409)
    else:
      OwnerResponse(code: 200, body: "{\"name\":\"radogost\",\"version\":10}")
  doAssert client(transport).upload("radogost", Bytes)["version"].getInt() == 10
  doAssert requests.len == 2
  doAssert parseJson(requests[1].body)["player_id"].getStr() == Player

echo "Testing rejected ownership cannot upload or complete"
block:
  var requests = 0
  let transport: OwnerTransport = proc(request: OwnerRequest): OwnerResponse =
    inc requests
    OwnerResponse(code: 403, body: "Wrong player credential")
  try:
    discard client(transport).upload("radogost", Bytes)
    doAssert false
  except OwnerError as error:
    doAssert error.msg.contains("HTTP 403")
  doAssert requests == 1

echo "Testing immutable regular-file bytes"
block:
  let
    directory = createTempDir("owner-file-test-", "")
    path = directory / "policy.bas"
  defer:
    removeDir(directory)
  writeFile(path, Bytes)
  let frozen = fileBody(path)
  writeFile(path, "different\n")
  doAssert frozen == Bytes

echo "Ownership upload tests passed"
