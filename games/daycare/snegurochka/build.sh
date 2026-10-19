#!/bin/sh
# Build and (optionally) upload the Snegurochka policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays scripted (the game container runs the LLM).
set -e
cd "$(dirname "$0")/../../.."
docker build -t snegurochka:latest -f games/daycare/snegurochka/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy snegurochka:latest \\"
echo "    --name snegurochka --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit snegurochka:vN -l league_b3316d91-3a90-41b6-9370-4c6644e51b9c"
