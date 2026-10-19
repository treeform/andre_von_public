#!/bin/sh
# Build and (optionally) upload the Stavr Godinovich policy.
# Scripted command player: credential-free, no secret envs required.
set -e
cd "$(dirname "$0")/../../.."
docker build -t stavr:latest -f games/cogsul/stavr/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy stavr:latest \\"
echo "    --name stavr --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit stavr:vN -l league_d5da6a4b-2dcd-4d46-81c6-69a310cc9e1a"
