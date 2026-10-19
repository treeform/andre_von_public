#!/bin/sh
# Build and (optionally) upload the Marya Iskusnitsa policy.
# Command player: no LLM, no secret-envs required.
set -e
cd "$(dirname "$0")/../../.."
docker build -t iskusnitsa:latest -f games/paintarena/iskusnitsa/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy iskusnitsa:latest \\"
echo "    --name iskusnitsa --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit iskusnitsa:vN -l league_d42210d6-1925-41a6-a47a-44f23524a3f6"
