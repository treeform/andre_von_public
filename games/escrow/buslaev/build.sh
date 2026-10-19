#!/bin/sh
# Build and (optionally) upload the Vasily Buslaev policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays scripted.
set -e
cd "$(dirname "$0")/../../.."
docker build -t buslaev:latest -f games/escrow/buslaev/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy buslaev:latest \\"
echo "    --name buslaev --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit buslaev:vN -l league_cc074076-5938-403e-81db-d278c031db6d"
