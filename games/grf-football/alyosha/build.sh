#!/bin/sh
# Build and (optionally) upload the Alyosha Popovich policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays the zonal baseline (docs/readme.md).
set -e
cd "$(dirname "$0")/../../.."
docker build -t alyosha:latest -f games/grf-football/alyosha/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy alyosha:latest \\"
echo "    --name alyosha --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit alyosha:vN -l league_973d55af-1df6-49b5-bb86-f3939993f65b"
