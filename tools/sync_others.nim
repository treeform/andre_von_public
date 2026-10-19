## Sync other players' published bots into others/<coworld>/<bot>/ from
## others/others.json. Playbook step 1: whenever a worker finds a
## published winning policy on GitHub, it records it in others.json and
## this tool checks it out for study. Checkouts are gitignored.
##   nim r tools/sync_others.nim          # everything
##   nim r tools/sync_others.nim <game>   # one game

import std/[json, os, osproc, strformat]

proc main() =
  let root = getCurrentDir()
  let map = parseJson(readFile(root / "others" / "others.json"))
  let only = if paramCount() >= 1: paramStr(1) else: ""
  var synced, failed = 0
  for game, bots in map.pairs:
    if game.len > 0 and game[0] == '_': continue
    if only.len > 0 and game != only: continue
    for bot, entry in bots.pairs:
      let repo = entry{"repo"}
      if repo.isNil or repo.kind != JString: continue
      let dir = root / "others" / game / bot
      if dirExists(dir / ".git"):
        discard execShellCmd(&"git -C {quoteShell(dir)} fetch -q --all")
      else:
        createDir(root / "others" / game)
        if execShellCmd(&"git clone -q https://github.com/{repo.getStr()} {quoteShell(dir)} 2>/dev/null") != 0 and
           execShellCmd(&"gh repo clone {repo.getStr()} {quoteShell(dir)} -- -q 2>/dev/null") != 0:
          echo &"FAILED {game}/{bot}: {repo.getStr()}"
          inc failed
          continue
      let pin = entry{"commit"}
      if not pin.isNil and pin.kind == JString:
        discard execShellCmd(&"git -C {quoteShell(dir)} checkout -q {pin.getStr()}")
      inc synced
  echo &"synced {synced}, failed {failed}"

main()
