#!/bin/sh
# Build and (optionally) upload the Volot policy.
# Scripted command player — NO secret-envs needed (no LLM seat).
# Optional env on upload: PLAYER_SCRIPTED=homesteader|raider (default homesteader).
set -e
cd "$(dirname "$0")/../../.."
docker build -t volot:latest -f games/territory/volot/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy volot:latest \\"
echo "    --name volot --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit volot:vN -l league_dcc3daee-8099-4fd1-b321-da10e1be9a64"
