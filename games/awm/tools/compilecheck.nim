## Compiles BASIC policy files against the AWM host without playing a game.
##
##   compilecheck FILE.bas [FILE.bas...]
##
## Prints "ok" or the compile error per file and exits nonzero on failure.

import
  std/[os],
  bots

proc main() =
  ## Loads each file into a bot VM and reports compile failures.
  var failed = false
  for k in 1 .. paramCount():
    let vms = loadBots([readFile(paramStr(k))])
    if vms[0].failed:
      echo paramStr(k), ": ", vms[0].lastError
      failed = true
    else:
      echo paramStr(k), ": ok"
  if failed:
    quit(1)

main()
