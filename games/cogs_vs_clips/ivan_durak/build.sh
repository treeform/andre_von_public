#!/bin/sh
# Build and (optionally) upload the Ivan Durak policy.
# Command player (no LLM seat): no USE_BEDROCK secret-env is needed.
set -e
cd "$(dirname "$0")/../../.."
docker build -t ivan_durak:latest -f games/cogs_vs_clips/ivan_durak/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy ivan_durak:latest \\"
echo "    --name ivan_durak --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  # Cogs vs Clips league:"
echo "  uv --project ~/p/metta run coworld submit ivan_durak:vN -l league_4a6999b2-6130-4489-987b-48d82ae769d2"
echo "  # Four Score league (needs 4 champions from 4 distinct players to round):"
echo "  uv --project ~/p/metta run coworld submit ivan_durak:vN -l league_4c38c53a-2cd5-4f98-8a1f-20830f733701"
