#!/bin/sh
# Build and (optionally) upload the Shamakhanskaya Tsaritsa cogiavelli policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the LLM seat
# silently plays the scripted condottiere baseline.
set -e
cd "$(dirname "$0")/../../.."
docker build -t shamakhanskaya:latest -f games/cogiavelli/shamakhanskaya/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy shamakhanskaya:latest \\"
echo "    --name shamakhanskaya --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit shamakhanskaya:vN -l league_5ba37909-d5ac-4ba5-8c51-842326b999e4"
