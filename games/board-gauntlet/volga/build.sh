#!/bin/sh
# Build and (optionally) upload the Volga Svyatoslavich policy for Board Gauntlet.
# Default seat is scripted tactician: no Bedrock sidecar required.
set -e
cd "$(dirname "$0")/../../.."
docker build -t volga:latest -f games/board-gauntlet/volga/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy volga:latest \\"
echo "    --name volga --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit volga:vN -l league_e96d74f3-745a-4308-86cf-0ed6489300e5"
