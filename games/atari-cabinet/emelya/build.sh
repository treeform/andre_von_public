#!/bin/sh
# Build and (optionally) upload the Emelya policy for THE CABINET (atari-cabinet).
# Upload needs --secret-env USE_BEDROCK=true: without it the platform gives
# the player pod no Bedrock sidecar and the seat silently plays scripted.
set -e
cd "$(dirname "$0")/../../.."
docker build -t emelya:latest -f games/atari-cabinet/emelya/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy emelya:latest \\"
echo "    --name emelya --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit emelya:vN -l league_20b10705-24f2-4d27-b7a0-31993f6110f7"
