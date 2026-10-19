#!/bin/sh
# Build and (optionally) upload the Sirin policy.
# Fully scripted spymaster: NO secret envs required (the game container
# runs the Sonnet operatives itself).
set -e
cd "$(dirname "$0")/../../.."
docker build -t sirin:latest -f games/cognames/sirin/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy sirin:latest \\"
echo "    --name sirin --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit sirin:vN -l league_f3c8b5da-5449-459b-81fd-fcaa62c90120"
