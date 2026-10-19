## Ruslan — Persistent Wow policy for Andre von Auto.
##
## Vendored andre-wow-walker:v82 — the exact submitted Persistent Wow
## lineage: the coworld-vanilla-wow reference player (canonical no-GUI
## semantic client plus the deterministic kobold-apologist leveling
## controller) from dependency branch persistent-wow-e30, commit
## b8b551f28f "avoid guessed quest returns". v82 cleared the promotion
## gate (mean score 2.95, +1258.7 XP over v23, all ten epochs to level
## two) and holds the league_778f16b8 champion seat as submission
## sub_b9ce70c8-48ac-4249-b14a-7e657748cded.
##
## The engine tree and every nimby.lock dependency are vendored once,
## under games/vanilla-wow/bova/vendor/ at their exact locked commits,
## and shared by both wow policies; nim.cfg next to this file points at
## that copy, so the Docker build needs no sibling checkout, no
## --build-context, and no SSH mounts. The reference player runs its
## scenario dispatch at module top level, so importing it is the whole
## program.
##
## Runtime contract (unchanged from upstream): the container starts
## `--scenario=coworld-session --bot=kobold-apologist`, consumes the
## hosted Coworld handoff from COWORLD_PLAYER_WS_URL in-process, and
## plays the durable character until the deadline.

import "../../vanilla-wow/bova/vendor/coworld/player/reference_player/reference_player"
