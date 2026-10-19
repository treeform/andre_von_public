#!/bin/sh
# Build and (optionally) upload the Govorun policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays scripted (docs/readme.md).
set -e
cd "$(dirname "$0")/../../.."
docker build -t govorun:latest -f games/garble/govorun/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy govorun:latest \\"
echo "    --name govorun --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit govorun:vN -l league_4eb352ae-4a7e-42a2-a7a2-6b3a23dc0b4a"
