# light-vs-dark tools

These games are `game-hosted`: the policy is a `.bas` file, so there is
no container to inspect and no wire log to extract. Local iteration runs
against the example's own headless binary instead.

Build it from a polyworld checkout at the commit the manifest names:

    cd ~/p/polyworld
    nim c -d:headless -d:release -o:/tmp/lvd examples/light_vs_dark/lvd.nim

Then use the shared ladder, which plays the candidate on both sides
because every one of these games has a favoured seat:

    nim r tools/polyworld_ladder.nim --game lvd --binary /tmp/lvd \
      --candidate games/light-vs-dark/<policy>/<policy>.bas \
      --baseline ~/p/polyworld/examples/light_vs_dark/players/base.bas \
      --seeds 12

Hosted results, replays and per-seat BASIC `PRINT` output come from the
platform: `coworld episodes`, `coworld episode-logs` and
`coworld replays`. `PRINT` goes to the owning player's private log only.
