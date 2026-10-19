#!/bin/sh
# Build and (optionally) upload the Tugarin Zmey policy.
# NO USE_BEDROCK secret-env: the LLM runs in the GAME container (the
# anthropic_api_key coworld secret is injected there), the player pod
# makes no LLM call (docs/protocol_player.md).
set -e
cd "$(dirname "$0")/../../.."
docker build -t tugarin:latest -f games/pommerman/tugarin/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy tugarin:latest \\"
echo "    --name tugarin --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit tugarin:vN -l league_7b53400d-b780-4024-924a-59bc2818dc8d"
