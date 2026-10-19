import
  std/[json, os],
  curly

type BuyanError = object of CatchableError

proc main() =
  ## Save a public hosted response for reproducible inspection.
  if paramCount() != 2:
    raise newException(BuyanError, "Expected URL and output path.")
  let client = newCurly()
  defer: client.close()
  let response = client.get(paramStr(1))
  if response.code != 200:
    raise newException(BuyanError, "Hosted request returned " &
      $response.code & ".")
  writeFile(paramStr(2), response.body)
  let data = parseJson(response.body)
  if data.kind == JObject:
    for key, value in data:
      echo key, ": ", value.kind, " ", value.len
  else:
    echo data.kind, " ", data.len

main()
