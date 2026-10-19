#!/bin/sh
# Build and (optionally) upload the Polevik policy.
# Fully scripted Kaggle-style agent (melonrush port): NO secret envs required.
set -e
cd "$(dirname "$0")/../../.."
docker build -t polevik:latest -f games/cogriculture/polevik/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy polevik:latest \\"
echo "    --name polevik --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit polevik:vN -l league_e2689e15-3d2b-4fab-8ac4-f78cf7d9cb00"
