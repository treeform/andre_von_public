#!/bin/sh
# Build and (optionally) upload the Shemyaka policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays the scripted tally baseline.
set -e
cd "$(dirname "$0")/../../.."
docker build -t shemyaka:latest -f games/tribunal/shemyaka/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy shemyaka:latest \\"
echo "    --name shemyaka --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit shemyaka:vN -l league_17699528-4b90-41b4-96e9-7e31a574e504"
