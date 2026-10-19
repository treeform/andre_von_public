#!/bin/sh
# Build and (optionally) upload the Sivka-Burka policy.
# Command player: it decides every step itself, so no USE_BEDROCK env.
set -e
cd "$(dirname "$0")/../../.."
docker build -t sivka_burka:latest -f games/jumper/sivka_burka/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy sivka_burka:latest \\"
echo "    --name sivka_burka --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit sivka_burka:vN -l league_f140dae4-e5fd-4d22-b8eb-67bc99e880ba"
