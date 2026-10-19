#!/bin/sh
# Build and (optionally) upload the Vasilisa Season 2 policy.
set -e
cd "$(dirname "$0")/../../.."
docker build --platform linux/amd64 -t vasilisa:latest -f games/paintbot/vasilisa/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld player use ply_3d22435e-30a2-4f2a-b037-a5c249583788"
echo "  uv --project ~/p/metta run coworld upload-policy vasilisa:latest --name vasilisa --run /bin/policy_player"
echo "submit (after XP verification; the user decides):"
echo "  uv --project ~/p/metta run coworld submit vasilisa:vN -l league_b8fa9b35-ac22-48cf-a03f-07b397aff1c7"
