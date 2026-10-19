#!/bin/sh
# Build and (optionally) upload the Svakha policy.
# Default seat is scripted hardliner — no Bedrock sidecar required.
# LLM override: PLAYER_SCRIPTED= PLAYER_PROMPT=... and USE_BEDROCK=true.
set -e
cd "$(dirname "$0")/../../.."
docker build -t svakha:latest -f games/negotiation-games/svakha/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy svakha:latest \\"
echo "    --name svakha --run /bin/policy_player"
echo "LLM override (not the default): add --secret-env USE_BEDROCK=true \\"
echo "  --secret-env PLAYER_SCRIPTED="
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit svakha:vN -l league_88e9052f-8e37-4f2e-aea1-ea4f5fdb20e7"
