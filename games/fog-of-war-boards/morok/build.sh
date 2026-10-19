#!/bin/sh
# Build and (optionally) upload the Morok policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays the probe baseline (docs/readme.md).
set -e
cd "$(dirname "$0")/../../.."
docker build -t morok:latest -f games/fog-of-war-boards/morok/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy morok:latest \\"
echo "    --name morok --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit morok:vN -l league_26ccabcd-af33-4f17-b9d7-f44626a7c625"
