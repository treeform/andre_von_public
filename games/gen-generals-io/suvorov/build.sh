#!/bin/sh
# Build and (optionally) upload the Suvorov policy.
# Secret-envs: none required — the GAME container holds the
# anthropic_api_key (docs/protocol_player.md: every decision is made in
# the game server) and the prompt is compiled into the binary. If a
# league round ever shows the seat silently playing sprawl, add
# --secret-env USE_BEDROCK=true (the grf-football precedent).
set -e
cd "$(dirname "$0")/../../.."
docker build -t suvorov:latest -f games/gen-generals-io/suvorov/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy suvorov:latest \\"
echo "    --name suvorov --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit suvorov:vN -l league_03508cde-90d2-43fa-a963-32265afd4737"
