#!/bin/sh
# Build and (optionally) upload the Morozko coins policy.
# Default seat is scripted reciprocator — no Bedrock sidecar required.
# LLM override: PLAYER_SCRIPTED= PLAYER_PROMPT=... and USE_BEDROCK=true.
set -e
cd "$(dirname "$0")/../../.."
docker build -t morozko:latest -f games/coins/morozko/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy morozko:latest \\"
echo "    --name morozko --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit morozko:vN -l league_e9506fcc-08c3-4372-90ac-0ced465c7d9c"
