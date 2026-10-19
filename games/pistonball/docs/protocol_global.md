# Pistonball — the global socket and the spectator surfaces

    GET /global      spectator snapshot, one binary Sprite v1 frame per tick

The board is PERFECT INFORMATION here, and only here: all twenty heads, the
ball, the trail, the contact puffs and up to three speech plates in the
reserved band at the top of the arena. This is the opposite of the player
socket, which is filtered to one metre either side of a single head.

## Chrome state rides the same binary channel

The broadcast chrome's JSON — clock, phase, scores, roster, bank, journey,
beats, endcard — is delivered as the LABEL of a reserved, never-drawn 1x1
sprite (id 4090) inside the same Sprite v1 packet as the board. It is not a
second socket and not a second recording, because a sidecar channel does not
survive a hosted replay and the label does.

The roster the chrome receives is the ONLY place the two name spaces meet: it
maps each anonymous alias (PST-nn) to the real policy name for the plates, the
locker room and the endcard. Nothing on a player socket ever carries one.

## The other routes

    GET /healthz          liveness
    GET /client/global    the spectator page (a real page, no player socket)
    GET /client/player    the seat-view page (ditto)
    GET /client/replay    the replay page (ditto)
    GET /replay-data      the episode's replay bytes

The three /client/ routes serve real pages because the certifier probes them
before it starts any player pod. None of them is how a spectator watches a
finished match: the platform viewer is the STATIC bundle
(`game.replay_viewer.bundle = "static-replay-viewer"`), which is served from
S3, fetches only its own `?replay=` URL, and never talks to a game pod.

## The replay

The binary COWLDPST format: magic + format version + game name/version header,
the RESOLVED config JSON (seed, perm, every geometry and physics constant, the
twenty rest heights, the roster with real names), then the record stream —
joins, leaves, per-tick input-change records (the command bytes the controller
produced), chat records (register / script / fallback / budget_guard / result)
and ONE gameHash per tick.

The static wasm viewer re-steps the SAME sim module the server ran from those
recorded command bytes and compares its own gameHash against the recorded one
every tick, so one divergent bit is caught at the tick it happens and reported
as `data-replay-mismatch-tick`. The viewer derives everything it draws from
that re-derivation; there is no parallel recording of positions.

`tools/replay_summary.py` (Python 3 stdlib only) prints one strict-UTF-8 JSON
object describing any .replay file — the config, the roster, every script
record and the results document.
