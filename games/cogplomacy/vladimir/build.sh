#!/bin/sh
# Build and (optionally) upload the Vladimir Krasno Solnyshko cogplomacy policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the LLM seat
# silently plays the scripted expander baseline.
set -e
cd "$(dirname "$0")/../../.."
docker build -t vladimir:latest -f games/cogplomacy/vladimir/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy vladimir:latest \\"
echo "    --name vladimir --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit vladimir:vN -l league_cb035e15-dbab-4478-9528-64a997be502a"
