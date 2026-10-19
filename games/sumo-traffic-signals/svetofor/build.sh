#!/bin/sh
# Build and (optionally) upload the Svetofor policy.
# NO secret-envs needed: docs/PROTOCOL.md says it outright — "No
# USE_BEDROCK flag is needed on a policy, because the player pod makes
# no LLM call"; the anthropic_api_key secret is injected into the GAME
# pod.
set -e
cd "$(dirname "$0")/../../.."
docker build -t svetofor:latest -f games/sumo-traffic-signals/svetofor/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy svetofor:latest \\"
echo "    --name svetofor --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit svetofor:vN -l league_0a4b0ef0-557c-4c54-b439-788cede68a73"
