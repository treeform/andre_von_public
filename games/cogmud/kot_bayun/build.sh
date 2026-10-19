#!/bin/sh
# Build and (optionally) upload the Kot Bayun cogmud policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the LLM seat
# silently plays the scripted factor baseline.
set -e
cd "$(dirname "$0")/../../.."
docker build -t kot_bayun:latest -f games/cogmud/kot_bayun/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy kot_bayun:latest \\"
echo "    --name kot_bayun --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit kot_bayun:vN -l league_c8ba20f2-f4b2-4e68-b8ad-ba75c5eca66a"
