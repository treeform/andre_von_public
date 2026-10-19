#!/bin/sh
# Build and (optionally) upload the Marya Morevna policy.
# Command player speaking Sprite v1 (binary): no LLM, no secret-envs required.
set -e
cd "$(dirname "$0")/../../.."
docker build -t morevna:latest -f games/paintbot/morevna/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy morevna:latest \\"
echo "    --name morevna --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion) to one of:"
echo "  uv --project ~/p/metta run coworld submit morevna:vN -l league_15cf0b94-6081-4750-9c8f-49493da4ced2  # Elite Paintbot"
echo "  uv --project ~/p/metta run coworld submit morevna:vN -l league_b8fa9b35-ac22-48cf-a03f-07b397aff1c7  # Paintbot"
echo "  uv --project ~/p/metta run coworld submit morevna:vN -l league_3243d905-d32d-4ec6-978b-fa94751d4a37  # Ctf"
