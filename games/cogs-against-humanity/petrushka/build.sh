#!/bin/sh
# Build and (optionally) upload the Petrushka policy.
# Scripted command player: credential-free, no secret envs required.
set -e
cd "$(dirname "$0")/../../.."
docker build -t petrushka:latest -f games/cogs-against-humanity/petrushka/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy petrushka:latest \\"
echo "    --name petrushka --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit petrushka:vN -l league_fac1e313-eedd-4dab-8b82-3f4fea2e4937"
