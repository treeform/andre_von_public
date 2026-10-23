## Runs a policy file on fast-XP (both seats, deterministic 0.1.11 engine)
## and prints the GCL of each seat plus the stats extractor summary.
## Usage: nim r tools/fastxp.nim <policy.js> <tag> [opponent policy_ref]
## Output lands in eps/fast/<tag>/ (replay, logs, summary).

import
  std/[json, os, osproc, strformat, strutils]

const
  Server = "https://fast-xp-k8s-prod.tail0f4a29.ts.net/v1/games/screeps-pw/run"

proc run(command: string): string =
  ## Runs a shell command and returns its output, raising on failure.
  let (output, code) = execCmdEx(command)
  if code != 0:
    raise newException(IOError, command & " failed:\n" & output)
  output

proc main() =
  let policy = paramStr(1)
  let tag = paramStr(2)
  let opponent = if paramCount() >= 3: paramStr(3) else: ""
  let root = currentSourcePath().parentDir.parentDir
  let dir = root / "eps" / "fast" / tag
  createDir(dir)
  let source = readFile(policy)
  var roster = newJArray()
  roster.add %*{"slot": 0, "player": {"source": source}}
  if opponent == "":
    roster.add %*{"slot": 1, "player": {"source": source}}
  else:
    roster.add %*{"slot": 1, "player": {"policy_ref": opponent}}
  let body = %*{"seed": 2026, "roster": roster, "num_episodes": 1}
  writeFile(dir / "request.json", $body)
  let zip = dir / "response.zip"
  for attempt in 0 ..< 6:
    let output = run(&"curl -s -m 7200 -X POST -H 'Content-Type: application/json' " &
      &"--data-binary @{quoteShell(dir / \"request.json\")} -o {quoteShell(zip)} " &
      &"-w '%{{http_code}}' {Server}")
    if output.strip() == "200":
      break
    if output.strip() == "429" and attempt < 5:
      sleep(5000 * (attempt + 1))
      continue
    raise newException(IOError, "fast-xp HTTP " & output & "\n" & readFile(zip))
  discard run(&"cd {quoteShell(dir)} && rm -rf out && mkdir out && unzip -q -o response.zip -d out")
  let stats = root / "tools" / "stats"
  var summary = ""
  for seat in 0 .. 1:
    let text = run(&"{stats} {quoteShell(dir / \"out\" / \"replay.replay\")} {seat} 100")
    writeFile(dir / &"seat{seat}.txt", text)
    for line in text.splitLines:
      if line.startsWith("seat ") or line.startsWith("harvested="):
        summary.add line & "\n"
  writeFile(dir / "summary.txt", summary)
  stdout.write summary

main()
