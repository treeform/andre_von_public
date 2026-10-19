#!/bin/sh
# Build and (optionally) upload the Anchutka policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays scripted (docs/policies.md).
set -e
cd "$(dirname "$0")/../../.."
docker build -t anchutka:latest -f games/matrix-games/anchutka/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy anchutka:latest \\"
echo "    --name anchutka --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit anchutka:vN -l league_2d6cdf8d-1f9d-4311-80ed-13616f5a8476"
