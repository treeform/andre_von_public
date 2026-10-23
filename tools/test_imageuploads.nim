import
  std/[osproc, strutils],
  imageuploads

proc tokens(arguments: openArray[string]): seq[string] =
  ## Runs shell quoting through printf without executing any player command.
  let (output, code) = execCmdEx(
    "printf '%s\\n' " & imageUploadFlags(arguments),
    options = {poUsePath, poStdErrToStdOut, poEvalCommand}
  )
  doAssert code == 0
  output.strip(leading = false, chars = {'\n'}).splitLines()

proc rejects(arguments: openArray[string]) =
  ## Requires malformed upload options to fail before any upload can start.
  var rejected = false
  try:
    discard imageUploadFlags(arguments)
  except ImageUploadError:
    rejected = true
  doAssert rejected

echo "Testing image upload options and shell quoting"
doAssert imageUploadFlags([]) == ""
doAssert tokens(["python", "-m", "policy", "--flag"]) == @[
  "--run=python", "--run=-m", "--run=policy", "--run=--flag"
]
doAssert tokens([
  "--bedrock-model=gpt-6.1-sol",
  "--use-bedrock",
  "--secret-env=KUTUZOV_ECONOMY_MODEL=gpt-6-luna",
  "python", "-m", "policy"
]) == @[
  "--bedrock-model=gpt-6.1-sol",
  "--use-bedrock",
  "--secret-env=KUTUZOV_ECONOMY_MODEL=gpt-6-luna",
  "--run=python", "--run=-m", "--run=policy"
]
doAssert tokens([
  "--secret-env=TEST_VALUE=a=b 'c' $(printf injected) `printf injected`",
  "argument with spaces; $(printf injected)", "", "--", "--use-bedrock"
]) == @[
  "--secret-env=TEST_VALUE=a=b 'c' $(printf injected) `printf injected`",
  "--run=argument with spaces; $(printf injected)", "--run=",
  "--run=--use-bedrock"
]
rejects(["--bedrock-model=gpt-6.1-sol"])
rejects(["--bedrock-model=", "--use-bedrock"])
rejects(["--use-bedrock", "--bedrock-model=a", "--bedrock-model=b"])
rejects(["--bedrock-model"])
rejects(["--secret-env"])
rejects(["--secret-env=VALUE"])
rejects(["--secret-env==value"])
rejects(["--secret-env=9NAME=value"])
rejects(["--secret-env=BAD-NAME=value"])
rejects(["--use-bedrock=true"])
echo "Image upload tests passed"
