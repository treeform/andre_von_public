#!/bin/sh
# Build and (optionally) upload the Zolotaya Rybka policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays scripted (the game container runs the LLM).
set -e
cd "$(dirname "$0")/../../.."
docker build -t zolotaya_rybka:latest -f games/cosino/zolotaya_rybka/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy zolotaya_rybka:latest \\"
echo "    --name zolotaya_rybka --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit zolotaya_rybka:vN -l league_673fa5a6-f5eb-4aa1-bc23-f066e290f8d6"
