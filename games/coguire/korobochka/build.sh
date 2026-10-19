#!/bin/sh
# Build and (optionally) upload the Korobochka policy.
# Pure scripted command player: NO secret-envs needed (no LLM seat).
set -e
cd "$(dirname "$0")/../../.."
docker build -t korobochka:latest -f games/coguire/korobochka/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy korobochka:latest \\"
echo "    --name korobochka --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit korobochka:vN -l league_e2b4266a-12fe-4e1e-9183-18230e6cae19"
