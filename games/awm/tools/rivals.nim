## Downloads the BASIC source of every policy version in the AWM league.
##
##   nim r -d:ssl games/awm/tools/rivals.nim [outdir]
##
## Hashes come from the elevated observatory SQL endpoint and the bytes from
## the private policy file bucket, read with the `softmax` AWS profile.

import
  std/[httpclient, json, os, osproc, strutils]

const
  SqlUrl = "https://softmax.com/api/observatory/sql/query"
  League = "ad6dc809-4696-46f5-99a5-fc2b1c58d082"
  Bucket = "s3://observatory-private/policies/files/"

proc userToken(): string =
  ## Returns the user bearer token from the shared credentials file.
  var inTokens = false
  let path = getHomeDir() / ".softmax/credentials.yaml"
  for line in readFile(path).splitLines:
    if line.startsWith("tokens:"):
      inTokens = true
    elif inTokens and "https" in line:
      return line.split(": ")[^1].strip(chars = {'"', ' '})
  quit("rivals: no user token in credentials.yaml", 1)

proc sql(query: string): JsonNode =
  ## Runs one elevated read-only SQL query and returns its rows.
  let client = newHttpClient(timeout = 60_000)
  defer:
    client.close()
  client.headers = newHttpHeaders({
    "Authorization": "Bearer " & userToken(),
    "X-Use-Elevated-Privileges": "true",
    "Content-Type": "application/json"
  })
  let body = parseJson(client.postContent(SqlUrl, $(%*{"query": query})))
  body["rows"]

proc main() =
  ## Lists league versions and downloads any source not yet on disk.
  let outdir =
    if paramCount() >= 1:
      paramStr(1)
    else:
      currentSourcePath().parentDir / "../others"
  createDir(outdir)
  let rows = sql(
    "select distinct p.name, pv.version, pv.player_id, " &
    "pv.player_file_content_hash, pv.created_at " &
    "from league_policy_memberships m " &
    "join policy_versions pv on pv.id = m.policy_version_id " &
    "join policies p on p.id = pv.policy_id " &
    "where m.league_id = '" & League & "' order by pv.created_at"
  )
  for row in rows:
    let
      name = row[0].getStr
      version = row[1].getInt
      player = row[2].getStr
      hash = row[3].getStr
      file = outdir / (name.replace(" ", "_") & "_v" & $version & ".bas")
    echo name, ":v", version, " ", player, " ", hash
    if hash.len == 0 or fileExists(file):
      continue
    let (output, code) = execCmdEx(
      "aws --profile softmax s3 cp " & quoteShell(Bucket & hash) & " " &
      quoteShell(file)
    )
    if code != 0:
      echo "  download failed: ", output.strip

main()
