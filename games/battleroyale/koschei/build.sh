#!/bin/sh
# Build and (optionally) upload the Koschei policy.
# Command player: no USE_BEDROCK secret needed — the bot decides itself.
set -e
cd "$(dirname "$0")/../../.."
docker build -t koschei:latest -f games/battleroyale/koschei/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy koschei:latest \\"
echo "    --name koschei --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit koschei:vN -l league_b88a269b-0de7-4723-b1c7-06dab50fe61d"
