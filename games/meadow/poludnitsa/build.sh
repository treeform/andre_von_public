#!/bin/sh
# Build and (optionally) upload the Poludnitsa policy.
# Scripted command player (enforcer port): no LLM, so no --secret-env is
# required.
set -e
cd "$(dirname "$0")/../../.."
docker build --platform linux/amd64 -t poludnitsa:latest \
  -f games/meadow/poludnitsa/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy poludnitsa:latest \\"
echo "    --name poludnitsa --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit poludnitsa:vN -l league_918134dc-1bf7-418e-833b-eb946c4cbeef"
