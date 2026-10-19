import std/[httpclient, os]

type MobaError = object of CatchableError

proc main() =
  ## Save an HTTP response without printing private payloads.
  if paramCount() != 2:
    raise newException(MobaError, "Usage: fetches URL output")
  let client = newHttpClient(timeout = 60_000)
  defer:
    client.close()
  try:
    let body = client.getContent(paramStr(1))
    createDir(parentDir(paramStr(2)))
    writeFile(paramStr(2), body)
    echo "Saved ", body.len, " bytes to ", paramStr(2)
  except CatchableError as error:
    raise newException(MobaError, "Fetch failed: " & error.msg)

main()
