#!/bin/sh
# Build and (optionally) upload the Chernobog policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays scripted.
set -e
cd "$(dirname "$0")/../../.."
docker build -t chernobog:latest -f games/hidden_agenda/chernobog/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy chernobog:latest \\"
echo "    --name chernobog --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit chernobog:vN -l league_9c44cf05-76f9-4ca5-8299-0c16a5e41ed9"
