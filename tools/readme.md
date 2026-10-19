# Shared tools

Common pieces every game policy uses.

- `coworld_client.nim` — websocket JSON client for the coworld player
  protocol (`COWORLD_PLAYER_WS_URL`). Policies import it, implement an
  `onMessage` callback, and call `run`.
- `Dockerfile.template` — standard two-stage Nim build (nimby 2.2.4 +
  whisky) producing a `/bin/policy_player` entrypoint. Copy per policy and
  replace `POLICY` with the policy module name.

## CLI cheat sheet

The coworld CLI runs from the metta repo:

    uv --project ~/p/metta run coworld <command>

- `coworld leagues [--json]` — all leagues on softmax.com
- `coworld show <cow_id> --json` — full manifest without pulling images
- `coworld download <cow_id>` — manifest + docker images (needed to run
  episodes locally or extract example player source)
- `coworld upload-policy <image>:latest -n <name> --run /bin/policy_player`
- `coworld submit <name>:vN -l <league_id>` (never `--auto-champion`)
- `coworld --elevated xp-request create <spec.json>` — hosted evaluation;
  batch many episodes into ONE request

Player identities: `coworld player list` / `coworld player use` —
this repo plays as **Andre von Auto** (`ply_3d22435e-30a2-4f2a-b037-a5c249583788`).

Scoring rules live in ../auto.md. Never score from local games; hosted
XP requests only, 10+ episodes, significance or revert.

## Uploads and submits: tools/auto_player only

Every policy upload and league submit goes through `tools/auto_player`
(`check`, `verify <name:vN>`, `upload <file> <name>`,
`upload-image <image> <name> [run argv]`, `submit <name:vN> <league>`).
Image uploads refresh the Auto session with `player use` first, because the
CLI binds them to the active player.
It makes Andre von Auto the active player with at least two hours of session
left (refreshing it with `coworld player use` when needed), refuses otherwise,
reads back the uploaded version's owner, and re-checks the owner before a
submit. The coworld CLI silently falls back to Andre von Houck when the Auto
session expires; that put khors versions under Houck twice. A PreToolUse hook in
`.claude/settings.json` blocks any raw `coworld upload-policy` / `coworld submit`.
Build: `nim c -d:ssl -o:tools/auto_player tools/auto_player.nim`. The CLI comes
from the stable metta worktree `~/p/metta-coworld-cli`.
