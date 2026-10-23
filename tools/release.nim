## Publish quiet games into the public mirror repo (andre_von_public).
## A game is released when nothing under games/<game> was committed for
## delayDays, unless it is in "hold"; games in "now" release regardless.
## Replay dumps, vendored and rival code (skipDirs) never leave this repo,
## nor do the exact paths listed in skipPaths.
##   nim r tools/release.nim            # copy, commit in the public repo
##   nim r tools/release.nim --dry-run  # only print what would happen
##   nim r tools/release.nim --push     # copy, commit and push

import std/[algorithm, json, os, osproc, re, sequtils, strformat, strutils, times]

const
  SecretPatterns = [
    r"AKIA[0-9A-Z]{16}",
    r"ghp_[A-Za-z0-9]{30,}",
    r"sk-ant-[A-Za-z0-9_-]{20,}",
    r"sk-[A-Za-z0-9]{32,}",
    r"-----BEGIN [A-Z ]*PRIVATE KEY-----",
    r"xox[abp]-[A-Za-z0-9-]{20,}"
  ]
  MaxScanBytes = 4_000_000

type
  Status = enum
    Released, Forced, Held, Active

  Game = object
    name: string
    slug: string
    commit: string
    date: string
    quietDays: int
    status: Status

proc run(cmd: string): string =
  ## Run a shell command and return its stdout, raising on failure.
  let (output, code) = execCmdEx(cmd)
  if code != 0:
    raise newException(OSError, &"command failed ({code}): {cmd}\n{output}")
  output

proc tracked(root, path: string): seq[string] =
  ## List git-tracked files under path, relative to root.
  let output = run(&"git -C {quoteShell(root)} ls-files -z {quoteShell(path)}")
  for piece in output.split('\0'):
    let line = piece.strip(chars = {'\n', '\r'})
    if line.len > 0:
      result.add(line)

proc skipped(path: string, skipDirs, skipPaths: seq[string]): bool =
  ## True when a directory component is in skipDirs or path is under skipPaths.
  let parts = path.split('/')
  for part in parts[0 ..< parts.len - 1]:
    if part in skipDirs:
      return true
  for prefix in skipPaths:
    if path == prefix or path.startsWith(prefix & "/"):
      return true
  false

proc copyTracked(root, pub, path: string,
    skipDirs, skipPaths: seq[string]): int =
  ## Copy tracked files under path from root into pub, returning the count.
  for file in tracked(root, path):
    if file.skipped(skipDirs, skipPaths):
      continue
    let dest = pub / file
    createDir(dest.parentDir)
    copyFileWithPermissions(root / file, dest)
    inc result

proc scanSecrets(pub: string, files: seq[string]): seq[string] =
  ## Return copied files whose contents match a secret pattern.
  let patterns = SecretPatterns.mapIt(re(it))
  for file in files:
    let path = pub / file
    if not fileExists(path) or getFileSize(path) > MaxScanBytes:
      continue
    let text = readFile(path)
    for pattern in patterns:
      if text.contains(pattern):
        result.add(file)
        break

proc gameInfo(root, name: string, names: JsonNode, delayDays: int,
    hold, now: seq[string]): Game =
  ## Describe one game directory: last commit, quiet days and release status.
  result.name = name
  result.slug = names{name, "slug"}.getStr("")
  let log = run(
    &"git -C {quoteShell(root)} log -1 --format=%h%x20%ct%x20%cs -- " &
    quoteShell("games" / name)
  ).strip()
  if log.len == 0:
    result.status =
      if name in hold:
        Held
      else:
        Active
    return
  let parts = log.split(' ')
  result.commit = parts[0]
  result.date = parts[2]
  result.quietDays = int((epochTime() - parseFloat(parts[1])) / 86400)
  result.status =
    if name in now:
      Forced
    elif name in hold:
      Held
    elif result.quietDays >= delayDays:
      Released
    else:
      Active

proc writeReleased(pub: string, games: seq[Game]) =
  ## Write RELEASED.md, the table of games present in the public repo.
  var lines = @[
    "# Released games",
    "",
    "Games below are snapshots of andre_von_auto taken after play on them",
    "stopped. Games still being played are not here yet.",
    "",
    "| Game | Policy | Source commit | Last change |",
    "| --- | --- | --- | --- |"
  ]
  for game in games:
    if dirExists(pub / "games" / game.name):
      lines.add(&"| {game.name} | {game.slug} | {game.commit} | {game.date} |")
  writeFile(pub / "RELEASED.md", lines.join("\n") & "\n")

proc main() =
  let
    root = getCurrentDir()
    config = parseJson(readFile(root / "release.json"))
    pub = absolutePath(root / config["public"].getStr())
    delayDays = config["delayDays"].getInt()
    hold = config["hold"].getElems().mapIt(it.getStr())
    now = config["now"].getElems().mapIt(it.getStr())
    skipDirs = config["skipDirs"].getElems().mapIt(it.getStr())
    skipPaths = config{"skipPaths"}.getElems().mapIt(it.getStr())
    shared = config["shared"].getElems().mapIt(it.getStr())
    names = parseJson(readFile(root / "games" / "names.json"))
    dryRun = "--dry-run" in commandLineParams()
    push = "--push" in commandLineParams()
  if not dirExists(pub / ".git"):
    raise newException(OSError, &"public repo not found at {pub}")

  var games: seq[Game]
  for kind, path in walkDir(root / "games"):
    if kind == pcDir:
      games.add(gameInfo(root, path.extractFilename, names, delayDays, hold, now))
  games.sort(proc(a, b: Game): int = cmp(a.name, b.name))

  var releasing: seq[string]
  for game in games:
    if game.status in {Released, Forced}:
      releasing.add(game.name)
    else:
      echo &"{game.status:<8} {game.quietDays:>3}d {game.name}"
  echo &"releasing {releasing.len} of {games.len} games"
  if dryRun:
    for name in releasing:
      echo &"  {name}"
    return

  var copied: seq[string]
  for name in releasing:
    removeDir(pub / "games" / name)
    discard copyTracked(root, pub, "games" / name, skipDirs, skipPaths)
    for file in tracked(root, "games" / name):
      if not file.skipped(skipDirs, skipPaths):
        copied.add(file)
  for path in shared:
    if dirExists(root / path):
      removeDir(pub / path)
    discard copyTracked(root, pub, path, skipDirs, skipPaths)
    for file in tracked(root, path):
      if not file.skipped(skipDirs, skipPaths):
        copied.add(file)
  writeReleased(pub, games)

  let leaks = scanSecrets(pub, copied)
  if leaks.len > 0:
    for file in leaks:
      echo &"SECRET? {file}"
    raise newException(ValueError,
      &"{leaks.len} files look like they hold secrets, nothing committed")

  discard run(&"git -C {quoteShell(pub)} add -A")
  let status = run(&"git -C {quoteShell(pub)} status --porcelain")
  if status.strip().len == 0:
    echo "public repo already up to date"
    return
  let changed = status.splitLines().filterIt(it.len > 0).len
  discard run(
    &"git -C {quoteShell(pub)} commit -q -m " &
    quoteShell(&"release {releasing.len} games, {changed} files")
  )
  echo &"committed {changed} changed files"
  if push:
    discard run(&"git -C {quoteShell(pub)} push")
    echo "pushed"

main()
