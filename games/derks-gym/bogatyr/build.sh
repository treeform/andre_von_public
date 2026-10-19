#!/bin/sh
# Build and (optionally) upload the Bogatyr policy.
# Scripted command player (lane-brawler port), zero model calls: no
# secret-envs required. (Only a PLAYER_PROMPT drafter seat would need
# --secret-env USE_BEDROCK=true for the Bedrock sidecar — docs/DRAFT.md.)
set -e
cd "$(dirname "$0")/../../.."
docker build -t bogatyr:latest -f games/derks-gym/bogatyr/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy bogatyr:latest \\"
echo "    --name bogatyr --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit bogatyr:vN -l league_44e55a9f-aa40-4523-9ed0-7f86ccc73d08"
