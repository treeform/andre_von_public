#!/bin/sh
# Build and (optionally) upload the stribog policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays scripted (league LLM seats, see tools/policy_conventions.md).
set -e
cd "$(dirname "$0")/../../.."
docker build -t stribog:latest -f games/particle-worlds/stribog/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy stribog:latest \\"
echo "    --name stribog --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit stribog:vN -l league_2ae87c04-15f1-4116-ad6d-54e0d656ea49"
