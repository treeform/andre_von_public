#!/bin/sh
# Build and (optionally) upload the Ilya Muromets policy (Muster).
# Scripted command player — no LLM, so NO secret-envs are required.
set -e
cd "$(dirname "$0")/../../.."
docker build -t ilya_muromets:latest -f games/Muster/ilya_muromets/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy ilya_muromets:latest \\"
echo "    --name ilya_muromets --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit ilya_muromets:vN -l league_d0f34381-669e-4f6a-9e7a-28ab16ce42e3"
