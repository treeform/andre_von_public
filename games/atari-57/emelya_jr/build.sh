#!/bin/sh
# Build and (optionally) upload the Emelya Jr policy for Atari 57.
# No LLM secret-env needed: the platform injects anthropic_api_key into the
# GAME pod (manifest runnable env) and every decision happens server-side.
# If a league seat ever plays scripted anyway, retry the upload with
# --secret-env USE_BEDROCK=true before digging deeper.
set -e
cd "$(dirname "$0")/../../.."
docker build -t emelya_jr:latest -f games/atari-57/emelya_jr/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy emelya_jr:latest \\"
echo "    --name emelya_jr --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit emelya_jr:vN -l league_942b4588-00ce-4b37-b5ae-9f1254d97db4"
