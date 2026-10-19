#!/bin/sh
# Build and (optionally) upload the Ognevushka policy.
# Default is PLAYER_SCRIPTED=conventions: no Bedrock sidecar required.
# LLM override: --secret-env USE_BEDROCK=true and PLAYER_SCRIPTED="".
set -e
cd "$(dirname "$0")/../../.."
docker build -t ognevushka:latest -f games/hanabi/ognevushka/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy ognevushka:latest \\"
echo "    --name ognevushka --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit ognevushka:vN -l league_332c17c5-b6bf-4341-98c7-3161dd58e6d8"
