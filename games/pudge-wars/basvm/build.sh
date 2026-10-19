#!/bin/sh
# Build and (optionally) upload the BASIC VM player (policy.bas = the local bot).
set -e
cd "$(dirname "$0")/../../.."
docker build --platform linux/amd64 -t myasnik-bas:latest -f games/pudge-wars/basvm/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld player use ply_3d22435e-30a2-4f2a-b037-a5c249583788"
echo "  uv --project ~/p/metta run coworld upload-policy myasnik-bas:latest --name myasnik-bas --run /bin/policy_player"
