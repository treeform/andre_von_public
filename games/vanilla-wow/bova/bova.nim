## Bova Korolevich — Vanilla Wow policy for Andre von Auto.
##
## Vendored andre-wow-walker:v82 lineage: the coworld-vanilla-wow
## reference player (canonical no-GUI semantic client plus the
## deterministic kobold-apologist leveling controller) from dependency
## branch persistent-wow-e30, commit b8b551f28f "avoid guessed quest
## returns" (see vendor/coworld/VENDORED_COMMIT). That build cleared the
## fresh-start promotion gate — every episode escaped the introductory
## quest loop, fought, looted, and reached level two — so the same
## controller is the base for the fresh-character Vanilla Wow leagues
## (Race / 10x / Arena / Dungeon).
##
## The engine tree and every nimby.lock dependency are vendored under
## vendor/ at their exact locked commits, so the Docker build needs no
## sibling checkout, no --build-context, and no SSH mounts. All build
## flags live in nim.cfg next to this file (mirroring the upstream
## wow-walker-persistent Dockerfile); the reference player runs its
## scenario dispatch at module top level, so importing it is the whole
## program.
##
## Runtime contract (unchanged from upstream): the container starts
## `--scenario=coworld-session --bot=kobold-apologist`, consumes the
## hosted Coworld handoff from COWORLD_PLAYER_WS_URL in-process, and
## plays until the deadline.

import vendor/coworld/player/reference_player/reference_player
