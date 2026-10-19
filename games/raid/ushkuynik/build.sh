#!/bin/sh
# Build and (optionally) upload the ushkuynik policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays scripted (league LLM seats, see tools/policy_conventions.md).
set -e
cd "$(dirname "$0")/../../.."
docker build -t ushkuynik:latest -f games/raid/ushkuynik/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy ushkuynik:latest \\"
echo "    --name ushkuynik --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit ushkuynik:vN -l league_7a5e52fa-e85e-41ab-8a66-418653b02de2"
