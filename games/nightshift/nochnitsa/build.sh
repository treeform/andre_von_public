#!/bin/sh
# Build and (optionally) upload the Nochnitsa policy.
# Scripted command player, zero model calls: no secret-envs required.
set -e
cd "$(dirname "$0")/../../.."
docker build -t nochnitsa:latest -f games/nightshift/nochnitsa/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy nochnitsa:latest \\"
echo "    --name nochnitsa --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit nochnitsa:vN -l league_f754def9-4850-43b9-af35-aebb9e98ebc9"
