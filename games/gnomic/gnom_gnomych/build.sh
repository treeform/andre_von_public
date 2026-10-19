#!/bin/sh
# Build and (optionally) upload the Gnom Gnomych policy.
# Scripted command player, zero model calls: no secret-envs required
# (the Elder/judge LLM runs in the game pod via its own judge_mode).
set -e
cd "$(dirname "$0")/../../.."
docker build -t gnom_gnomych:latest -f games/gnomic/gnom_gnomych/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy gnom_gnomych:latest \\"
echo "    --name gnom_gnomych --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit gnom_gnomych:vN -l league_4788bdc9-67da-4b00-a8e2-265a8169e7f7"
