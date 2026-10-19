#!/bin/sh
# Build and (optionally) upload the Gruzchik policy.
# No USE_BEDROCK secret-env needed: the anthropic_api_key coworld secret
# is injected into the GAME pod, which makes every decision — the seat
# only registers its prompt (docs/actions.md, docs/protocol_player.md).
set -e
cd "$(dirname "$0")/../../.."
docker build -t gruzchik:latest -f games/sokoban/gruzchik/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy gruzchik:latest \\"
echo "    --name gruzchik --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit gruzchik:vN -l league_81761ec5-88ed-4a94-b9b5-89d8b93b90fe"
