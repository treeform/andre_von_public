## Builds a policy variant by overriding Tune values and runs it on fast-XP.
## Usage: nim r tools/sweep.nim <base.js> <tag> key=value ...
## Values are inserted verbatim into `  key: ...,` lines of the Tune block.

import
  std/[os, osproc, strutils]

proc main() =
  let base = paramStr(1)
  let tag = paramStr(2)
  let root = currentSourcePath().parentDir.parentDir
  let dir = root / "eps" / "fast" / tag
  createDir(dir)
  var lines = readFile(base).splitLines
  var notes: seq[string]
  for i in 3 .. paramCount():
    let arg = paramStr(i)
    let key = arg[0 ..< arg.find('=')]
    let value = arg[arg.find('=') + 1 .. ^1]
    var found = false
    for j in 0 ..< lines.len:
      let line = lines[j]
      if line.startsWith("  " & key & ":"):
        let comment = line.find("//")
        let tail = if comment >= 0: " " & line[comment .. ^1] else: ""
        let comma = if line.strip().endsWith(",") or comment >= 0 and
          line[0 ..< comment].strip().endsWith(","): "," else: ""
        lines[j] = "  " & key & ": " & value & comma & tail
        found = true
        # Drop continuation lines of a multi-line array value.
        let opens = line.count('[') - line.count(']')
        if opens > 0:
          var depth = opens
          while depth > 0 and j + 1 < lines.len:
            depth += lines[j + 1].count('[') - lines[j + 1].count(']')
            lines.delete(j + 1)
        break
    if not found:
      raise newException(ValueError, "No Tune key " & key)
    notes.add arg
  let policy = dir / "policy.js"
  writeFile(policy, lines.join("\n"))
  writeFile(dir / "overrides.txt", notes.join(" ") & "\n")
  let (output, code) = execCmdEx(root / "tools" / "fastxp" & " " &
    quoteShell(policy) & " " & tag)
  echo tag, " ", notes.join(" ")
  stdout.write output
  if code != 0:
    raise newException(IOError, "fastxp failed")

main()
