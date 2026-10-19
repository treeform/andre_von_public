#!/bin/sh
# Build and (optionally) upload the Zvezdochet policy.
# Command player: it decides every step itself, so no USE_BEDROCK env.
# Remember the qualification gate: a submitted policy only becomes
# champion after winning a self-play 47-planet wipeout episode.
set -e
cd "$(dirname "$0")/../../.."
docker build -t zvezdochet:latest -f games/planet_wars/zvezdochet/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy zvezdochet:latest \\"
echo "    --name zvezdochet --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit zvezdochet:vN -l league_074c818a-fe56-42a4-a2de-1a79202f281a"
