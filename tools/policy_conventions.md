# Policy conventions

Every game folder `games/<game>/` contains:

- `manifest.json` — the coworld manifest (docs, example players, schemas).
- `docs/` — rules/protocol pages extracted from the manifest. A file that
  says `External doc: <url>` is a stub; fetch the URL (for github blob
  links use raw.githubusercontent.com) to read the real doc.
- `ideas.md` — the game's dossier: description, leagues, example players,
  baseline notes, ideas backlog, experiment log.
- `tools/` — game-specific replay/log extractors (Nim).
- `<slug>/` — THE policy, named after a Russian folklore character
  (see `games/names.json`). Contains:
  - `<slug>.nim` — the policy. Nim only.
  - `Dockerfile` — two-stage nimby build, built from the REPO ROOT.
  - `build.sh` — docker build + upload/submit cheat lines.

## The two policy shapes

**Prompt seat** (most cogame-engine games): the player container is thin —
it connects to `COWORLD_PLAYER_WS_URL`, sends one hello frame carrying an
operator prompt (or scripted baseline name), then only listens until
`final`. The game container runs the LLM and makes every decision. The
Nim policy embeds a crafted strategy prompt (that prompt IS the strategy)
and follows the game's exact wire protocol — field names differ per game,
always read the protocol doc. Exemplar:
`games/matrix-games/anchutka/anchutka.nim`.

Upload note for prompt seats: league LLM seats usually need
`--secret-env USE_BEDROCK=true` or the seat silently plays scripted.

**Command player**: the container makes decisions itself — receives
observations, replies with actions every step. Port the strongest
available baseline logic to Nim. Exemplar of the message loop:
`tools/coworld_client.nim` (see also `~/p/dinky/coworld_player.nim`).

## Style

- Full English word names (`request`, not `req`); `i/j/k/n/id` stay short.
- No kind-prefix enums: `IdentToken`, never `tkIdent`.
- No ASCII banner dividers; short `## Title` comments.
- Must pass: `cd /Users/me/p/andre_von_auto && nim check --hints:off games/<game>/<slug>/<slug>.nim`
  (the repo-root nim.cfg provides whisky + tools paths).

## ideas.md additions per policy

Add before `## Ideas backlog`:

    ## Baseline

    Which example is the default, which is strongest, what our policy
    does, required upload secret-envs.

And put 5+ concrete improvement ideas in the backlog.


## Winning

Before iterating on any game's strategy, read `tools/winning_playbook.md`:
hunt published winning policies, read the sim source for exploits, re-check
the sim on every version bump, and use the MCTS + steering loop for board
games.

## Never

- Never `git commit`, `docker build`, `upload-policy`, or `submit` from a
  policy-writing agent — the operator does that centrally.
- Never `--auto-champion`. Only the user promotes champions.
- Never score from local games; hosted XP requests only (see ../auto.md).
