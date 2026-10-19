#!/bin/sh
# Build and (optionally) upload the Vasilisa Premudraya cogchemists policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the LLM seat
# silently plays the scripted assayer baseline.
set -e
cd "$(dirname "$0")/../../.."
docker build -t vasilisa:latest -f games/cogchemists/vasilisa/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy vasilisa:latest \\"
echo "    --name vasilisa --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit vasilisa:vN -l league_7a7ba378-a709-4b1a-b8c1-b21b6577025a"
