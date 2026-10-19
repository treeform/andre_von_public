#!/bin/sh
# Build and (optionally) upload the Balda policy.
# Fully scripted (reference implementations + pre-verified tests baked in):
# NO secret envs required.
set -e
cd "$(dirname "$0")/../../.."
docker build -t balda:latest -f games/cogolf/balda/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy balda:latest \\"
echo "    --name balda --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit balda:vN -l league_4cb6dc9b-be72-44f7-8713-1b6fc9e1880c"
