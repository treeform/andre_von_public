#!/bin/sh
# Build and (optionally) upload the Zhar-Ptitsa policy.
# Default is scripted hauler: no Bedrock sidecar. LLM override still
# needs --secret-env USE_BEDROCK=true or the seat plays hauler anyway
# (docs/policies.md).
set -e
cd "$(dirname "$0")/../../.."
docker build -t zhar_ptitsa:latest -f games/fruit-market/zhar_ptitsa/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy zhar_ptitsa:latest \\"
echo "    --name zhar_ptitsa --run /bin/policy_player"
echo "LLM override (not the default): add --secret-env USE_BEDROCK=true \\"
echo "  --secret-env PLAYER_SCRIPTED="
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit zhar_ptitsa:vN -l league_758061e3-46cb-49db-aef0-a28fb10ba80e"
