## Fetches submitted policy files through Observatory's policy-file download
## route (elevated user token), for pw_diag only. The user authorized this
## on 2026-09-29: keep the files outside the repo, use them only to run the
## diagnostics, and delete them afterwards.
##
##   nim c -d:ssl -o:tools/pw_fetch tools/pw_fetch.nim
##   tools/pw_fetch <out dir> <name:vN> [<name:vN> ...]

import
  std/[httpclient, json, os, osproc, sequtils, strutils]

const
  DownloadUrl = "https://softmax.com/api/observatory/v2/policy-files/download?policy_ref="

proc userToken(): string =
  ## Returns the user bearer token from the softmax credentials file.
  var inTokens = false
  for line in readFile(getHomeDir() / ".softmax/credentials.yaml").splitLines:
    if line.startsWith("tokens:"):
      inTokens = true
    elif inTokens and "https" in line:
      return line.split(": ")[^1].strip(chars = {'"', ' '})
  quit("pw_fetch: no user token", 1)

proc sha256(path: string): string =
  ## Returns the SHA-256 of a file in lowercase hex.
  let (output, code) = execCmdEx("shasum -a 256 " & quoteShell(path))
  if code != 0:
    quit("pw_fetch: shasum failed", 1)
  output.splitWhitespace[0].toLowerAscii

proc fetch(outDir, policyRef: string) =
  ## Downloads one policy file and verifies its hash and size.
  let api = newHttpClient(timeout = 60_000)
  api.headers = newHttpHeaders({
    "Authorization": "Bearer " & userToken(),
    "X-Use-Elevated-Privileges": "true"
  })
  let response = api.get(DownloadUrl & policyRef)
  if not response.code.is2xx:
    echo policyRef, ": HTTP ", response.code, " ",
      response.body[0 ..< min(300, response.body.len)]
    return
  let info = parseJson(response.body)
  var
    url, hash: string
    size = -1
  for key, value in info:
    let k = key.toLowerAscii
    if value.kind == JString and "url" in k:
      url = value.getStr
    elif value.kind == JString and ("sha" in k or "hash" in k):
      hash = value.getStr.toLowerAscii
    elif value.kind == JInt and ("size" in k or "bytes" in k):
      size = value.getInt
  if url == "":
    echo policyRef, ": no url, keys ", toSeq(info.keys).join(",")
    return
  let body = newHttpClient(timeout = 120_000).getContent(url)
  createDir(outDir)
  let
    extension =
      if body.len > 1 and body[0] == 'P' and body[1] == 'K':
        ".zip"
      else:
        ".bas"
    path = outDir / policyRef.replace(':', '_') & extension
  writeFile(path, body)
  let digest = sha256(path)
  if (hash != "" and digest != hash) or (size >= 0 and body.len != size):
    removeFile(path)
    echo policyRef, ": hash or size mismatch, discarded"
    return
  echo policyRef, ": ", body.len, " bytes, sha256 ok -> ", path

proc main() =
  if paramCount() < 2:
    quit("usage: pw_fetch <out dir> <name:vN>...", 2)
  for i in 2 .. paramCount():
    fetch(paramStr(1), paramStr(i))

main()
