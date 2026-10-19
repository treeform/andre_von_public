#!/bin/sh
# Build and (optionally) upload the Dazhbog policy.
# No Bedrock flag needed: the LLM call is made by the GAME container,
# which is where the platform injects the coworld secret
# (games/lux-ai/docs/readme.md). A seat that never registers plays
# scripted forester, so verify the register record after upload.
set -e
cd "$(dirname "$0")/../../.."
docker build -t dazhbog:latest -f games/lux-ai/dazhbog/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy dazhbog:latest \\"
echo "    --name dazhbog --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit dazhbog:vN -l league_91cd77d4-0030-495d-81c4-37de0b298801"
