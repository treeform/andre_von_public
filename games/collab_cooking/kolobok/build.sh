#!/bin/sh
# Build and (optionally) upload the Kolobok policy.
# Default is scripted runner, so no Bedrock flag is required. LLM override
# (empty PLAYER_SCRIPTED) needs --secret-env USE_BEDROCK=true.
set -e
cd "$(dirname "$0")/../../.."
docker build -t kolobok:latest -f games/collab_cooking/kolobok/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy kolobok:latest \\"
echo "    --name kolobok --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit kolobok:vN -l league_592e6ed0-3f01-4084-bb90-75ace0db0063"
