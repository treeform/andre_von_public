#!/bin/sh
# Build and (optionally) upload the Seryi Volk policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the prompt seat
# silently plays scripted (the game container runs the LLM planner).
set -e
cd "$(dirname "$0")/../../.."
docker build -t seryi_volk:latest -f games/cooperative_hunting/seryi_volk/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy seryi_volk:latest \\"
echo "    --name seryi_volk --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit seryi_volk:vN -l league_500b6882-6374-43f4-a82b-5e2d0522d9fd"
