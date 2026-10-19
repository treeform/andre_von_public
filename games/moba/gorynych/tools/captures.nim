import std/[os, osproc, streams]

type MobaError = object of CatchableError

proc main() =
  ## Capture a command's output with explicit argument boundaries.
  if paramCount() < 2:
    raise newException(MobaError, "Usage: captures output command args")
  let
    arguments = commandLineParams()
    process = startProcess(
      arguments[1],
      args = arguments[2 .. ^1],
      options = {poUsePath, poStdErrToStdOut}
    )
  defer:
    process.close()
  createDir(parentDir(arguments[0]))
  let output = open(arguments[0], fmWrite)
  defer:
    output.close()
  var line: string
  while process.outputStream.readLine(line):
    output.writeLine(line)
    output.flushFile()
  let code = process.waitForExit()
  echo "Exit ", code, "; output: ", arguments[0]
  quit(code)

main()
