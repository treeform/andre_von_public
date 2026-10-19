#!/bin/sh
# Build and (optionally) upload the Svyatogor policy. Command player:
# no LLM seat, so no USE_BEDROCK secret-env is needed.
set -e
cd "$(dirname "$0")/../../.."
docker build --platform linux/amd64 -t svyatogor:latest \
  -f games/bw/svyatogor/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy svyatogor:latest \\"
echo "    --name svyatogor --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit svyatogor:vN -l league_803e98eb-1e5a-4b09-bf96-0f15b326e26a"
