#!/bin/sh
# Build and (optionally) upload the Skazochnik policy for Procgen.
# No LLM secret-env needed: the platform injects anthropic_api_key into the
# GAME pod (manifest runnable env) and every decision happens server-side.
# If a league seat ever plays scripted anyway, retry the upload with
# --secret-env USE_BEDROCK=true before digging deeper.
set -e
cd "$(dirname "$0")/../../.."
docker build -t skazochnik:latest -f games/procgen/skazochnik/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy skazochnik:latest \\"
echo "    --name skazochnik --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit skazochnik:vN -l league_2b1f9007-0749-4e3c-a669-a630283894f1"
