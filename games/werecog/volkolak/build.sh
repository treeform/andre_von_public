#!/bin/sh
# Build and (optionally) upload the Volkolak policy.
# Deterministic command player — NO secret-envs needed (no LLM seat).
set -e
cd "$(dirname "$0")/../../.."
docker build -t volkolak:latest -f games/werecog/volkolak/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy volkolak:latest \\"
echo "    --name volkolak --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit volkolak:vN -l league_01dfa32d-0587-4793-8a29-b917cec01fde"
