#!/bin/sh
# Build and (optionally) upload the vakula policy.
# No LLM secret-env needed: default is scripted wavebot. LLM override
# still needs --secret-env USE_BEDROCK=true (tools/policy_conventions.md).
set -e
cd "$(dirname "$0")/../../.."
docker build -t vakula:latest -f games/pistonball/vakula/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy vakula:latest \\"
echo "    --name vakula --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit vakula:vN -l league_6789db33-ab0a-4b15-b572-b3ea39c614fd"
