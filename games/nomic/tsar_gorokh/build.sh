#!/bin/sh
# Build and (optionally) upload the Tsar Gorokh policy.
# Scripted command player, zero model calls: no secret-envs required.
set -e
cd "$(dirname "$0")/../../.."
docker build -t tsar_gorokh:latest -f games/nomic/tsar_gorokh/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy tsar_gorokh:latest \\"
echo "    --name tsar_gorokh --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit tsar_gorokh:vN -l league_ee2f409e-20a9-4501-ad4d-14116bc4b4a0"
