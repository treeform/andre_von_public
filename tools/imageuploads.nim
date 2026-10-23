import std/[os, strutils]

type
  ImageUploadError* = object of CatchableError

proc imageUploadFlags*(arguments: openArray[string]): string =
  ## Quotes upload options and preserves remaining arguments as player argv.
  var
    useBedrock = false
    hasModel = false
    runOnly = false
  for argument in arguments:
    if not runOnly and argument == "--":
      runOnly = true
    elif not runOnly and argument == "--use-bedrock":
      useBedrock = true
      result.add " --use-bedrock"
    elif not runOnly and argument.startsWith("--bedrock-model="):
      let model = argument["--bedrock-model=".len .. ^1]
      if model.len == 0 or hasModel:
        raise newException(ImageUploadError, "Specify one nonempty model")
      hasModel = true
      result.add " --bedrock-model=" & quoteShell(model)
    elif not runOnly and argument.startsWith("--secret-env="):
      let
        assignment = argument["--secret-env=".len .. ^1]
        separator = assignment.find('=')
      if separator <= 0:
        raise newException(ImageUploadError, "Secret env requires KEY=VALUE")
      for i in 0 ..< separator:
        let character = assignment[i]
        if character notin {'A' .. 'Z', 'a' .. 'z', '_'} and
          (i == 0 or character notin {'0' .. '9'}):
            raise newException(ImageUploadError, "Invalid secret env name")
      result.add " --secret-env=" & quoteShell(assignment)
    elif not runOnly and (argument in ["--bedrock-model", "--secret-env"] or
      argument.startsWith("--use-bedrock=")):
        raise newException(ImageUploadError,
          "Use --use-bedrock, --bedrock-model=MODEL or --secret-env=KEY=VALUE")
    else:
      result.add " --run=" & quoteShell(argument)
  if hasModel and not useBedrock:
    raise newException(ImageUploadError, "Model requires --use-bedrock")
