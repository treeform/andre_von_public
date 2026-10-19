#!/bin/sh
# Build and (optionally) upload the Ivanushka policy.
# Default is scripted porter (no Bedrock flag). LLM override needs
# --secret-env USE_BEDROCK=true and PLAYER_SCRIPTED="".
set -e
cd "$(dirname "$0")/../../.."
docker build -t ivanushka:latest -f games/tandem/ivanushka/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy ivanushka:latest \\"
echo "    --name ivanushka --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit ivanushka:vN -l league_50c18e88-ed54-4cd7-be36-4748d79b5a9b"
