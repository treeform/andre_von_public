#!/bin/sh
# Build and (optionally) upload the Buyan policy for nmmo.
# A command player: no LLM, no secret-envs needed.
set -e
cd "$(dirname "$0")/../../.."
docker build -t buyan:latest -f games/nmmo/buyan/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy buyan:latest \\"
echo "    --name buyan --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit buyan:vN -l league_d7e141f9-ee29-4a46-b15c-5bbdb1639a44"
