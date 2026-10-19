#!/bin/sh
# Build and (optionally) upload the Lisa Patrikeevna policy.
# Scripted command player (Bayesian reference port): no LLM, so no
# --secret-env is required.
set -e
cd "$(dirname "$0")/../../.."
docker build --platform linux/amd64 -t lisa:latest \
  -f games/liars-cog/lisa/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy lisa:latest \\"
echo "    --name lisa --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit lisa:vN -l league_358a52d3-e9f4-44bd-bb0a-2f08816c5ca0"
