#!/bin/sh
# Build and (optionally) upload the Zlydni policy.
# Pure scripted command player: NO secret-envs needed (no LLM seat).
# Never set CTF_BOT_FAST_READY in league play (0x85 corrupts input timing).
set -e
cd "$(dirname "$0")/../../.."
docker build -t zlydni:latest -f games/emerg-ant/zlydni/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy zlydni:latest \\"
echo "    --name zlydni --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit zlydni:vN -l league_485b7b0a-5a52-4254-9b2b-1e10b9596941"
