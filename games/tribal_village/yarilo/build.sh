#!/bin/sh
# Build and (optionally) upload the Yarilo policy.
# No LLM seat: the mirror is fully scripted, so no USE_BEDROCK needed.
set -e
cd "$(dirname "$0")/../../.."
docker build -t yarilo:latest -f games/tribal_village/yarilo/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy yarilo:latest \\"
echo "    --name yarilo --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit yarilo:vN -l league_aedc4933-a75a-40ab-aaef-1653e0796875"
