#!/bin/sh
# Build and (optionally) upload the Stepan policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays scripted.
set -e
cd "$(dirname "$0")/../../.."
docker build -t stepan:latest -f games/firm/stepan/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy stepan:latest \\"
echo "    --name stepan --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit stepan:vN -l league_31edf62a-9174-4975-b39b-cd1555853bff"
