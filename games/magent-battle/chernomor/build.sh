#!/bin/sh
# Build and (optionally) upload the Chernomor policy.
# No Bedrock flag needed: every decision is made inside the game
# server, the only container the platform injects the
# anthropic_api_key coworld secret into (docs/PROTOCOL.md, external).
# A seat that never registers plays scripted pincer, so verify the
# register record after upload.
set -e
cd "$(dirname "$0")/../../.."
docker build -t chernomor:latest -f games/magent-battle/chernomor/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy chernomor:latest \\"
echo "    --name chernomor --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit chernomor:vN -l league_b56ff3be-1f0f-4b2a-b2e7-c44d17839134"
