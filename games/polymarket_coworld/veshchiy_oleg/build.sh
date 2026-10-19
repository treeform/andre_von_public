#!/bin/sh
# Build and (optionally) upload the Veshchiy Oleg policy.
# Command player: it makes every decision itself, so NO USE_BEDROCK or
# other secret-envs are required.
set -e
cd "$(dirname "$0")/../../.."
docker build -t veshchiy_oleg:latest -f games/polymarket_coworld/veshchiy_oleg/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy veshchiy_oleg:latest \\"
echo "    --name veshchiy_oleg --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit veshchiy_oleg:vN -l league_545782b2-4ad1-4345-a5be-5539357166d5"
