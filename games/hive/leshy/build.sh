#!/bin/sh
# Build and (optionally) upload the Leshy policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays scripted.
set -e
cd "$(dirname "$0")/../../.."
docker build -t leshy:latest -f games/hive/leshy/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy leshy:latest \\"
echo "    --name leshy --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit leshy:vN -l league_2d1d904b-5465-4b84-9845-b28164d22f7e"
