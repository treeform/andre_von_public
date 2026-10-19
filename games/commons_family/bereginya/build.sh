#!/bin/sh
# Build and (optionally) upload the Bereginya policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays scripted (the game container runs the LLM).
set -e
cd "$(dirname "$0")/../../.."
docker build -t bereginya:latest -f games/commons_family/bereginya/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy bereginya:latest \\"
echo "    --name bereginya --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit bereginya:vN -l league_a95d0e60-1042-4981-bcdc-ead449bfa783"
