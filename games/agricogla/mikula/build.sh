#!/bin/sh
# Build and (optionally) upload the Mikula Selyaninovich policy.
# Vendored terra champion (terra:v268 lineage): scripted MCTS command
# player, no LLM seat — no USE_BEDROCK or other secret-envs needed.
# Solver tuning envs (TERRA_SOLVER_*) default to the champion settings.
set -e
cd "$(dirname "$0")/../../.."
docker build --platform linux/amd64 -t mikula:latest \
  -f games/agricogla/mikula/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy mikula:latest \\"
echo "    --name mikula --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit mikula:vN -l league_b81baeb4-0e1b-4e71-b162-08f46b2b6a45"
