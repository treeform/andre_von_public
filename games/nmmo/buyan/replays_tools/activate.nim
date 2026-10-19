## CLI: activate <plan.json> <evidence.json>
## Prints statistics activation JSON on stdout.

import
  std/[json, os],
  activations

if paramCount() != 2:
  stderr.writeLine "usage: activate <plan.json> <evidence.json>"
  quit(1)
try:
  echo pretty(activate(paramStr(1), paramStr(2)))
except NmmoActivationError as err:
  stderr.writeLine err.msg
  quit(1)
