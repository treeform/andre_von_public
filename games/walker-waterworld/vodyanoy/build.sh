#!/bin/sh
# Build and (optionally) upload the Vodyanoy policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays the scripted shoal baseline.
set -e
cd "$(dirname "$0")/../../.."
docker build -t vodyanoy:latest -f games/walker-waterworld/vodyanoy/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy vodyanoy:latest \\"
echo "    --name vodyanoy --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit vodyanoy:vN -l league_69fe3c37-8208-4e14-b575-331e1d018d9b"
