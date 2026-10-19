#!/bin/sh
# Build and (optionally) upload the Gvidon policy (CitySim).
# Scripted command player — no LLM, so NO secret-envs are required.
set -e
cd "$(dirname "$0")/../../.."
docker build -t gvidon:latest -f games/citysim/gvidon/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy gvidon:latest \\"
echo "    --name gvidon --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit gvidon:vN -l league_46f4e2c2-ca12-480c-bf95-fdeb0f891cd2"
