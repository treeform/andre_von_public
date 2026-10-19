#!/bin/sh
# Build and (optionally) upload the Elena Premudraya policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays scripted.
set -e
cd "$(dirname "$0")/../../.."
docker build -t elena_premudraya:latest -f games/eleusis/elena_premudraya/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy elena_premudraya:latest \\"
echo "    --name elena_premudraya --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit elena_premudraya:vN -l league_0e95b506-422e-4339-9a9d-8c8a6ecdb4ea"
