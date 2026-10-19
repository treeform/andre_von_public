#!/bin/sh
# Build and (optionally) upload the Domovoy policy.
# Scripted command player: credential-free, no secret envs required.
set -e
cd "$(dirname "$0")/../../.."
docker build -t domovoy:latest -f games/cogtan/domovoy/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy domovoy:latest \\"
echo "    --name domovoy --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit domovoy:vN -l league_26c4376a-ec17-4de8-88e9-4e8cf081721d"
