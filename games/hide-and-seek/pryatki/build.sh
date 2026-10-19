#!/bin/sh
# Build and (optionally) upload the Pryatki policy for Hide And Seek.
# No LLM secret-env needed: the platform injects anthropic_api_key into the
# GAME pod (manifest runnable env) and every decision happens server-side.
# If a league seat ever plays scripted anyway, retry the upload with
# --secret-env USE_BEDROCK=true before digging deeper.
set -e
cd "$(dirname "$0")/../../.."
docker build -t pryatki:latest -f games/hide-and-seek/pryatki/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy pryatki:latest \\"
echo "    --name pryatki --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit pryatki:vN -l league_7931991b-df9e-4248-98ca-c613dac7137d"
