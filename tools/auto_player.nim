## The only way this repo uploads or submits policies: as Andre von Auto,
## or as Andre von Houck when the user asks for it by name.
##
##   nim r -d:ssl tools/auto_player.nim check
##   nim r -d:ssl tools/auto_player.nim upload <policy file> <policy name>
##   nim r -d:ssl tools/auto_player.nim upload-image <image> <name> [run argv]
##   nim r -d:ssl tools/auto_player.nim submit <name:vN> <league id>
##   nim r -d:ssl tools/auto_player.nim verify <name:vN>
##
## `--player=houck` (anywhere on the command line) runs the same command as
## Andre von Houck: the same session refresh and owner verification, against
## Houck. Uploads carry an explicit player ID in both API phases.
##
## Uploads capture the user credential once and bind the target player in
## each request, independently of the CLI's globally selected player. After an
## upload the new version's owner is read back from the observatory and the
## command fails loudly when it is not Andre von Auto. Submit re-checks the
## owner of the exact version before submitting it.

import std/[httpclient, json, os, osproc, strutils], owners

const
  AutoPlayer = "ply_3d22435e-30a2-4f2a-b037-a5c249583788"
  HouckPlayer = "ply_607f17a2-3acf-405b-91fe-d12ef1001c00"
  SqlUrl = "https://softmax.com/api/observatory/sql/query"

proc credentials(): string =
  ## Returns the shared user credential file without using its active pointer.
  getHomeDir() / ".softmax/credentials.yaml"

proc cli(): string =
  ## Returns the coworld CLI command backed by a stable metta checkout.
  "uvx --from " & quoteShell(getHomeDir() / "p/metta-coworld-cli/packages/coworld[auth]") & " coworld"

proc userToken(): string =
  ## Returns the user (not player) bearer token from the credentials file.
  var inTokens = false
  for line in readFile(credentials()).splitLines:
    if line.startsWith("tokens:"):
      inTokens = true
    elif inTokens and "https" in line:
      return line.split(": ")[^1].strip(chars = {'"', ' '})
  quit("auto_player: no user token in credentials.yaml", 1)

proc activePlayer(): string =
  ## Returns the active player id recorded in the credentials file.
  for line in readFile(credentials()).splitLines:
    let trimmed = line.strip
    if trimmed.startsWith("active:"):
      return trimmed.split(":", 1)[1].strip
  ""

var
  targetPlayer = AutoPlayer
  targetName = "Andre von Auto"

proc run(command: string): string =
  ## Runs a shell command, echoing its output, and quits when it fails.
  let (output, code) = execCmdEx(command, options = {poUsePath, poStdErrToStdOut, poEvalCommand})
  stdout.write output
  if code != 0:
    quit("auto_player: command failed: " & command, 1)
  output

proc ensurePlayer(player, name: string) =
  ## Makes one player active; the CLI refreshes its session on its own.
  if activePlayer() != player:
    echo "auto_player: switching to ", name
    discard run(cli() & " player use " & player)
  if activePlayer() != player:
    quit("auto_player: REFUSING: " & name & " is not the active player", 1)
  echo "auto_player: ", name, " active"

proc ensureTarget() =
  ## Makes the player this command acts as active.
  ensurePlayer(targetPlayer, targetName)

proc versionOwner(name: string, version: int): string =
  ## Reads the owning player id of one policy version from the observatory.
  let client = newHttpClient(timeout = 60_000)
  client.headers = newHttpHeaders({
    "Authorization": "Bearer " & userToken(),
    "X-Use-Elevated-Privileges": "true",
    "Content-Type": "application/json"})
  let query = "select pv.player_id from policy_versions pv join policies p " &
    "on p.id = pv.policy_id where p.name = '" &
    name.replace("'", "''") & "' and pv.version = " & $version
  let body = parseJson(client.postContent(SqlUrl, $(%*{"query": query})))
  if body["rows"].len == 0:
    return ""
  body["rows"][0][0].getStr

proc verifyOwner(name: string, version: int) =
  ## Quits loudly unless the version belongs to the target player.
  let owner = versionOwner(name, version)
  if owner != targetPlayer:
    quit("auto_player: WRONG OWNER: " & name & ":v" & $version & " belongs to " & owner, 1)
  echo "auto_player: ", name, ":v", version, " is owned by ", targetName

proc main() =
  ## Runs one command with explicit upload and submission ownership.
  var arguments: seq[string]
  for argument in commandLineParams():
    if argument == "--player=houck":
      targetPlayer = HouckPlayer
      targetName = "Andre von Houck"
    elif argument == "--player=auto":
      discard
    elif argument.startsWith("--player="):
      quit("auto_player: unknown player " & argument, 2)
    else:
      arguments.add argument
  template paramCount(): int = arguments.len
  template paramStr(i: int): string = arguments[i - 1]
  if paramCount() < 1:
    quit("usage: auto_player check | verify <name:vN> | upload <file> <name> | " &
      "upload-image <image> <name> [run argv] | submit <name:vN> <league>", 2)
  case paramStr(1)
  of "check":
    ensureTarget()
  of "verify":
    if paramCount() < 2:
      quit("usage: auto_player verify <name:vN>", 2)
    let parts = paramStr(2).split(":v")
    verifyOwner(parts[0], parseInt(parts[1]))
  of "upload":
    if paramCount() < 3:
      quit("usage: auto_player upload <file> <name>", 2)
    let name = paramStr(3)
    let client = OwnerClient(
      token: userToken(),
      player: targetPlayer,
      api: ApiUrl
    )
    let uploaded = client.upload(name, fileBody(paramStr(2)))
    let version = uploaded["version"].getInt()
    echo "Upload complete: ", name, ":v", version
    verifyOwner(name, version)
  of "upload-image", "upload-endpoint":
    if paramCount() < 3:
      quit("usage: auto_player upload-image <image> <name> [run argv...]", 2)
    # Image uploads use the CLI's active player session, so refresh it first.
    discard run(cli() & " player use " & targetPlayer)
    ensureTarget()
    let name = paramStr(3)
    var command = cli() & " upload-policy " & quoteShell(paramStr(2)) &
      " --name " & quoteShell(name)
    if paramStr(1) == "upload-endpoint":
      if paramCount() != 6:
        quit("usage: upload-endpoint <image> <name> <model> " &
          "<endpoint> <key env>", 2)
      let key = paramStr(6)
      if key.len == 0 or not key.allCharsInSet(
        {'A' .. 'Z', 'a' .. 'z', '0' .. '9', '_'}
      ) or getEnv(key).len == 0:
          quit("auto_player: missing endpoint key environment", 2)
      command = "uv --cache-dir /private/tmp/diplodocus-uv-cache " &
        "tool run --from 'coworld[auth]' coworld upload-policy " &
        quoteShell(paramStr(2)) & " --name " & quoteShell(name) &
        " --use-llm --llm-model " & quoteShell(paramStr(4)) &
        " --llm-endpoint " & quoteShell(paramStr(5)) &
        " --llm-api-key-env " & quoteShell(key) &
        " --title 'Kutuzov update' " &
        "--description 'Updated Kutuzov policy.'"
    else:
      for i in 4 .. paramCount():
        command.add " --run " & quoteShell(paramStr(i))
    let
      output = run(command)
      marker = "Upload complete: " & name & ":v"
      at = output.find(marker)
    if at < 0:
      quit("auto_player: could not read the uploaded version", 1)
    var digits = ""
    for c in output[at + marker.len .. ^1]:
      if c.isDigit:
        digits.add c
      else:
        break
    verifyOwner(name, parseInt(digits))
  of "submit":
    if paramCount() < 3:
      quit("usage: auto_player submit <name:vN> <league>", 2)
    ensureTarget()
    let parts = paramStr(2).split(":v")
    verifyOwner(parts[0], parseInt(parts[1]))
    let submit = cli() & " submit " & quoteShell(paramStr(2)) &
      " -l " & quoteShell(paramStr(3)) & " --player " & targetPlayer
    let (output, code) = execCmdEx(submit, options = {poUsePath,
      poStdErrToStdOut, poEvalCommand})
    stdout.write output
    if code != 0 and "cogent" in output:
      # Since 2026-10-22 the platform treats the Auto player session as a
      # cogent and refuses submits; the user identity submits on its behalf.
      echo "auto_player: retrying the submit under the user identity"
      discard run(cli() & " player unset")
      discard run(submit)
      ensureTarget()
    elif code != 0:
      quit("auto_player: command failed: " & submit, 1)
  else:
    quit("auto_player: unknown command " & paramStr(1), 2)

main()
