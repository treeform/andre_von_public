## Sync game simulation checkouts into sims/<game>/ from sims/sims.json.
## Each game maps to candidate GitHub repos (mined from its manifest) and
## an optional pinned commit. Checkouts are gitignored; sims.json is the
## committed source of truth. Run after any game version bump, then diff:
##   nim r tools/sync_sims.nim            # clone/fetch everything
##   nim r tools/sync_sims.nim <game>     # just one game
## Private repos use whatever auth `git`/`gh` already has.

import std/[json, os, osproc, strformat, strutils]

proc sh(cmd: string): int =
  execShellCmd(cmd)

proc main() =
  let root = getCurrentDir()
  let sims = parseJson(readFile(root / "sims" / "sims.json"))
  let only = if paramCount() >= 1: paramStr(1) else: ""
  var cloned, skipped, failed = 0
  for game, entry in sims.pairs:
    if only.len > 0 and game != only: continue
    let repos = entry{"repos"}
    if repos.isNil or repos.len == 0:
      inc skipped
      continue
    let dir = root / "sims" / game
    # First candidate repo that clones wins; game-named repos first.
    var candidates: seq[string]
    for r in repos:
      let name = r.getStr()
      if game.replace("_","-") in name.toLowerAscii() or
         game.replace("-","_") in name.toLowerAscii():
        candidates.insert(name, 0)
      else:
        candidates.add(name)
    if dirExists(dir / ".git"):
      discard sh(&"git -C {quoteShell(dir)} fetch -q --all")
    else:
      var ok = false
      for c in candidates:
        if sh(&"git clone -q https://github.com/{c} {quoteShell(dir)} 2>/dev/null") == 0 or
           sh(&"gh repo clone {c} {quoteShell(dir)} -- -q 2>/dev/null") == 0:
          ok = true
          break
      if not ok:
        echo &"FAILED {game}: none of {candidates} cloned"
        inc failed
        continue
    let pin = entry{"pinned_commit"}
    if not pin.isNil and pin.kind == JString and pin.getStr().len > 0:
      discard sh(&"git -C {quoteShell(dir)} checkout -q {pin.getStr()}")
    inc cloned
  echo &"synced {cloned}, skipped {skipped} (no repo hint), failed {failed}"

main()
