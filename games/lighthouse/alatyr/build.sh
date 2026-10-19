#!/bin/sh
# Build and (optionally) upload the Alatyr policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays scripted (tools/policy_conventions.md).
set -e
cd "$(dirname "$0")/../../.."
docker build -t alatyr:latest -f games/lighthouse/alatyr/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy alatyr:latest \\"
echo "    --name alatyr --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit alatyr:vN -l league_3e9fc4b5-5b6c-4ad7-8ff4-e74fa144d954"
