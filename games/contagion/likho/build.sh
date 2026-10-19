#!/bin/sh
# Build and (optionally) upload the Likho policy.
# Default is scripted sentinel: no Bedrock flag required. LLM override
# (empty PLAYER_SCRIPTED) still needs --secret-env USE_BEDROCK=true.
set -e
cd "$(dirname "$0")/../../.."
docker build -t likho:latest -f games/contagion/likho/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy likho:latest \\"
echo "    --name likho --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit likho:vN -l league_53d9ccfb-c943-4b5c-a89f-b9b149365df1"
