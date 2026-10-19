#!/bin/sh
# Build and (optionally) upload the Finist Yasny Sokol policy.
# Default is scripted tactician, so no Bedrock flag is required.
# LLM seats need --secret-env USE_BEDROCK=true and PLAYER_SCRIPTED="" .
set -e
cd "$(dirname "$0")/../../.."
docker build -t finist:latest -f games/focus/finist/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy finist:latest \\"
echo "    --name finist --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit finist:vN -l league_a27cd3f2-d1ba-4f8a-be5f-93e583affa11"
