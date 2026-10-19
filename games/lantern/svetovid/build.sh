#!/bin/sh
# Build and (optionally) upload the Svetovid policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays scripted.
set -e
cd "$(dirname "$0")/../../.."
docker build -t svetovid:latest -f games/lantern/svetovid/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy svetovid:latest \\"
echo "    --name svetovid --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit svetovid:vN -l league_16893be5-934d-43b4-9155-d27f600ffffe"
