#!/bin/sh
# Build and (optionally) upload the Belobog policy.
# Deterministic command player — NO secret-envs needed (no LLM seat).
set -e
cd "$(dirname "$0")/../../.."
docker build -t belobog:latest -f games/zero-sum/belobog/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy belobog:latest \\"
echo "    --name belobog --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit belobog:vN -l league_6764202e-2ac1-4c98-a77e-cabc75582939"
