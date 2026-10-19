#!/bin/sh
# Build and (optionally) upload the Moska policy.
# Scripted command player, zero model calls: no secret-envs required.
set -e
cd "$(dirname "$0")/../../.."
docker build -t moska:latest -f games/nomic-fable/moska/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy moska:latest \\"
echo "    --name moska --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit moska:vN -l league_33f50eed-02ae-4b80-92d9-536cb900a15a"
