#!/bin/sh
# Build and (optionally) upload the Konyok-Gorbunok policy for Flatland.
# NO USE_BEDROCK secret-env: the anthropic key is injected into the GAME
# pod and the player pod makes no LLM call (docs/protocol_player.md).
set -e
cd "$(dirname "$0")/../../.."
docker build -t gorbunok:latest -f games/flatland/gorbunok/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy gorbunok:latest \\"
echo "    --name gorbunok --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit gorbunok:vN -l league_b8ffbdda-2f8f-45af-b905-e600ba385cff"
