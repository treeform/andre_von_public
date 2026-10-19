#!/bin/sh
# Build and (optionally) upload the Svarog policy.
# Command player: no USE_BEDROCK secret needed — the bot decides itself.
set -e
cd "$(dirname "$0")/../../.."
docker build -t svarog:latest -f games/infinite_blocks/svarog/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy svarog:latest \\"
echo "    --name svarog --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit svarog:vN -l league_ab1cc8ce-365c-488b-84c3-7ebc5156b71d"
