#!/bin/sh
# Build and (optionally) upload the Pikovaya Dama policy.
# Default is PLAYER_SCRIPTED=tracker: no Bedrock sidecar required.
# LLM override: --secret-env USE_BEDROCK=true and PLAYER_SCRIPTED="".
set -e
cd "$(dirname "$0")/../../.."
docker build -t pikovaya_dama:latest -f games/trick-taking/pikovaya_dama/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy pikovaya_dama:latest \\"
echo "    --name pikovaya-dama --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit pikovaya-dama:vN -l league_4764b49e-5b40-40b6-bd3d-3ed1b7bd8aa0"
