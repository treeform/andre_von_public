#!/bin/sh
# Build and (optionally) upload the Kroshechka policy.
# No USE_BEDROCK secret-env needed: the anthropic_api_key coworld secret
# is injected into the GAME pod, which makes every decision — the seat
# only registers its prompt (docs/protocol_player.md).
set -e
cd "$(dirname "$0")/../../.."
docker build -t kroshechka:latest -f games/minigrid/kroshechka/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy kroshechka:latest \\"
echo "    --name kroshechka --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit kroshechka:vN -l league_78d5b417-52a0-4459-8fd6-3b9aeacfe1ca"
