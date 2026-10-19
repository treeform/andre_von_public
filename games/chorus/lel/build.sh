#!/bin/sh
# Build and (optionally) upload the Lel policy for Chorus.
# Upload needs --secret-env USE_BEDROCK=true: without it the platform gives
# the player pod no Bedrock sidecar and the seat silently plays scripted.
set -e
cd "$(dirname "$0")/../../.."
docker build -t lel:latest -f games/chorus/lel/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy lel:latest \\"
echo "    --name lel --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit lel:vN -l league_472f2259-1529-44a4-937f-50deb5e3be63"
