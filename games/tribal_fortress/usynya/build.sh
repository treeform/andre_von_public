#!/bin/sh
# Build and (optionally) upload the Usynya policy.
# Usynya is a command player (no LLM seat): no USE_BEDROCK secret needed.
# No other secret-envs are required either. Optional plain envs:
#   USYNYA_RENDER=0 forces the passive bot-socket fallback in fortress mode.
set -e
cd "$(dirname "$0")/../../.."
docker build -t usynya:latest -f games/tribal_fortress/usynya/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy usynya:latest \\"
echo "    --name usynya --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  # Tribal Quest league"
echo "  uv --project ~/p/metta run coworld submit usynya:vN -l league_e5a2e816-7b65-41f5-9ff0-e74ada0d9d3d"
echo "  # Tribal Fortress league"
echo "  uv --project ~/p/metta run coworld submit usynya:vN -l league_37dc6573-071c-4c6b-a6c5-301a006ad20b"
