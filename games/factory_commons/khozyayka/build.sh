#!/bin/sh
# Build and (optionally) upload the Khozyayka Mednoy Gory policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays scripted.
set -e
cd "$(dirname "$0")/../../.."
docker build -t khozyayka:latest -f games/factory_commons/khozyayka/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy khozyayka:latest \\"
echo "    --name khozyayka --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit khozyayka:vN -l league_96744093-0ddc-42dc-b5bf-79f195f062f0"
