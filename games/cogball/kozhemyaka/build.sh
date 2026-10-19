#!/bin/sh
# Build and (optionally) upload the Nikita Kozhemyaka cogball policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the LLM seat
# silently plays the scripted formation baseline.
set -e
cd "$(dirname "$0")/../../.."
docker build -t kozhemyaka:latest -f games/cogball/kozhemyaka/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy kozhemyaka:latest \\"
echo "    --name kozhemyaka --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit kozhemyaka:vN -l league_e87130ef-ecc6-49d4-9bc1-4014b7141df5"
