#!/bin/sh
# Build and (optionally) upload the Zmey Gorynych policy for moba.
# A command player: no LLM, no secret-envs needed.
set -e
cd "$(dirname "$0")/../../.."
docker build -t gorynych:latest -f games/moba/gorynych/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy gorynych:latest \\"
echo "    --name gorynych --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit gorynych:vN -l league_becba59f-4201-43a5-9cd6-970bd92857d9"
