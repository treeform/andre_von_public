#!/bin/sh
# Build and (optionally) upload the Gamayun policy for Babel.
# Upload needs --secret-env USE_BEDROCK=true: without it the platform gives
# the player pod no Bedrock sidecar and the seat silently plays scripted.
set -e
cd "$(dirname "$0")/../../.."
docker build -t gamayun:latest -f games/babel/gamayun/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy gamayun:latest \\"
echo "    --name gamayun --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit gamayun:vN -l league_6ae669f0-5e32-4efd-b363-76bd7f44b240"
