import std/[json, os], budgets, engines, logs, players

proc main() =
  ## Start the Nim policy underneath the webDiplomacy lifecycle launcher.
  if paramCount() == 1 and paramStr(1) == "--version":
    echo "kutuzov v1, gpt-6.1-sol low"
    return
  logEvent("process_start", %*{"version": "v1", "nim_version": NimVersion})
  try:
    if loadBudgetConfig().toolLoop:
      runToolBot()
    else:
      runBot()
    logEvent("process_return", %*{"exit_code": 0})
  except Exception as error:
    logError("fatal", error)
    logEvent("process_return", %*{"exit_code": 1})
    quit(1)

main()
