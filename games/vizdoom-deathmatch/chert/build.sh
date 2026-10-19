#!/bin/sh
# Build and (optionally) upload the Chert policy for Vizdoom Deathmatch.
# No LLM secret-env needed: the platform injects anthropic_api_key into the
# GAME pod (manifest runnable env) and every decision happens server-side.
# If a league seat ever plays scripted anyway, retry the upload with
# --secret-env USE_BEDROCK=true before digging deeper.
set -e
cd "$(dirname "$0")/../../.."
docker build -t chert:latest -f games/vizdoom-deathmatch/chert/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy chert:latest \\"
echo "    --name chert --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit chert:vN -l league_00dcb926-7f23-4507-8a2d-6684cb0e7c4b"
