#!/bin/sh
# Build and (optionally) upload the ovinnik policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays scripted (league LLM seats, see tools/policy_conventions.md).
set -e
cd "$(dirname "$0")/../../.."
docker build -t ovinnik:latest -f games/rware-warehouse/ovinnik/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy ovinnik:latest \\"
echo "    --name ovinnik --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit ovinnik:vN -l league_05193716-123a-4941-a7c7-16a9643ebe37"
