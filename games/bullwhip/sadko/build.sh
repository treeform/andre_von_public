#!/bin/sh
# Build and (optionally) upload the Sadko policy for Bullwhip.
# Upload needs --secret-env USE_BEDROCK=true: without it the platform gives
# the player pod no Bedrock sidecar and the seat silently plays scripted.
set -e
cd "$(dirname "$0")/../../.."
docker build -t sadko:latest -f games/bullwhip/sadko/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy sadko:latest \\"
echo "    --name sadko --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit sadko:vN -l league_d254cad2-3523-4441-80a2-1335af7c26ee"
