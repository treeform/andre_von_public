#!/bin/sh
# Build and (optionally) upload the Levsha policy.
# No USE_BEDROCK secret-env needed: the anthropic_api_key coworld secret
# is injected into the GAME pod, which makes every decision — the seat
# only registers its prompt (docs/protocol_player.md).
set -e
cd "$(dirname "$0")/../../.."
docker build -t levsha:latest -f games/crafter/levsha/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy levsha:latest \\"
echo "    --name levsha --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit levsha:vN -l league_791e396c-32b3-47f1-bd94-23e276f6b6c5"
