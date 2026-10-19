#!/bin/sh
# Build and (optionally) upload the Danila Master policy.
# Scripted command player (burner baseline port): no LLM, so no
# --secret-env is required.
set -e
cd "$(dirname "$0")/../../.."
docker build --platform linux/amd64 -t danila:latest \
  -f games/factorio/danila/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy danila:latest \\"
echo "    --name danila --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit danila:vN -l league_09df6929-74d3-45ae-8857-4bb69d2880d1"
