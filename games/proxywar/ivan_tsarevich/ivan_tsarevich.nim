## Ivan Tsarevich — Proxy War policy for Andre von Auto.
## Sends the Grey Wolf to fight for him: a thin main over our kutuzov
## ladder bot (~/p/proxywar), whose V98 champion is live rank one on the
## Proxy War ladder. Modules started as that submitted-V98 copy; the
## local default now adds a closing-phase ground companion on top.
##
## Command player: scores every offered LegalAction.id and answers with
## the argmax, plus V98's funded economy batch companion and a closing-
## phase ground companion. Profile selection: `--profile=<name>` argv
## wins, then PROXYWAR_PROFILE, and with neither we default to the
## closing-ground profile below (upstream defaults to weaker "base"
## weights).

import std/[os, strutils]
import proxywar

const championProfile = "openingSoftPangaeaPeaceEconomyBatchGround"

when isMainModule:
  var hasProfileArgument = false
  for index in 1 .. paramCount():
    if paramStr(index).startsWith("--profile="):
      hasProfileArgument = true
  if not hasProfileArgument and getEnv("PROXYWAR_PROFILE").len == 0:
    putEnv("PROXYWAR_PROFILE", championProfile)
  main()
