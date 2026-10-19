#!/bin/sh
# Build and (optionally) upload the Baba Yaga policy for Chemistry.
# Upload needs --secret-env USE_BEDROCK=true: without it the platform gives
# the player pod no Bedrock sidecar and the seat silently plays scripted.
set -e
cd "$(dirname "$0")/../../.."
docker build -t baba_yaga:latest -f games/chemistry/baba_yaga/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy baba_yaga:latest \\"
echo "    --name baba_yaga --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit baba_yaga:vN -l league_9b734c36-c6a2-4cc4-a12e-e8bc3977e86c"
