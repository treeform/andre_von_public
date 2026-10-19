#!/bin/sh
# Build and (optionally) upload the Peresvet policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays the scripted focusfire baseline.
set -e
cd "$(dirname "$0")/../../.."
docker build -t peresvet:latest -f games/smac-starcraft-micro/peresvet/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy peresvet:latest \\"
echo "    --name peresvet --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit peresvet:vN -l league_f42b4821-882b-428e-b803-630671e86726"
