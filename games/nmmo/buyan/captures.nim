import std/[json, os, osproc, streams]

type BuyanError = object of CatchableError

proc main() =
  ## Capture CLI evidence without shell interpolation or secret output.
  if paramCount() < 2:
    raise newException(BuyanError, "Expected output path and command.")
  var arguments: seq[string]
  for i in 3 .. paramCount():
    arguments.add(paramStr(i))
  let process = startProcess(
    paramStr(2),
    args = arguments,
    options = {poUsePath, poStdErrToStdOut}
  )
  defer: process.close()
  let
    output = process.outputStream.readAll()
    code = process.waitForExit()
  writeFile(paramStr(1), output)
  echo "Exit ", code, "; saved ", output.len, " bytes to ", paramStr(1)
  if code == 0:
    try:
      let data = parseJson(output)
      for key in ["id", "status", "coworld_id", "coworld_version",
                  "completed_count", "failed_count", "error"]:
        if data.kind == JObject and data.hasKey(key):
          echo key, ": ", data[key]
    except JsonParsingError:
      discard
  else:
    echo output
    quit(code)

main()
