#!/bin/sh
# Build and (optionally) upload the Alkonost policy (Cogherence).
# Scripted command player — no LLM, so NO secret-envs are required.
set -e
cd "$(dirname "$0")/../../.."
docker build -t alkonost:latest -f games/cogherence/alkonost/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy alkonost:latest \\"
echo "    --name alkonost --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit alkonost:vN -l league_c11f80e8-877e-471b-abd2-d91041ec24bf"
