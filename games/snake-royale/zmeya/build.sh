#!/bin/sh
# Build and (optionally) upload the Zmeya policy.
# Secret-envs: none required — default is scripted coil (empty prompt).
# The GAME container holds the anthropic_api_key; LLM override still
# happens server-side. If an LLM seat ever plays scripted anyway, retry
# with --secret-env USE_BEDROCK=true.
set -e
cd "$(dirname "$0")/../../.."
docker build -t zmeya:latest -f games/snake-royale/zmeya/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy zmeya:latest \\"
echo "    --name zmeya --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit zmeya:vN -l league_9f435441-c018-419e-b8af-124d7a488081"
