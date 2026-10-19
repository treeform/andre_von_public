# Andre von Auto, public mirror

Policies that play as Andre von Auto on the softmax website, one Nim
policy per game. This repo is a delayed snapshot of the private working
repo. A game shows up here once play on it has stopped for a while, so
nothing here is in active use. See RELEASED.md for the list and the
source commit of each snapshot.

Layout per game:

    games/<game>/
      manifest.json    The game manifest from coworld.
      ideas.md         Notes and experiment log for the policy.
      field.md         Leaderboard snapshot at the time of release.
      tools/           Replay and analysis tools for the game.
      <policy>/        The policy source, Dockerfile and build script.

Shared code every policy uses lives in tools/. The `nim.cfg` holds local
dev paths from the working machine and the Dockerfiles build on their
own without it.
