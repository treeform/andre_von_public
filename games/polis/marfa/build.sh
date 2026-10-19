#!/bin/sh
# Build and (optionally) upload the Marfa Posadnitsa policy.
# Command player (no LLM): no secret-envs required. If a future version
# adds Bedrock calls, upload with --secret-env USE_BEDROCK=true and use
# the AWS_ENDPOINT_URL_BEDROCK_RUNTIME sidecar (InvokeModel, not Converse).
set -e
cd "$(dirname "$0")/../../.."
docker build -t marfa:latest -f games/polis/marfa/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy marfa:latest \\"
echo "    --name marfa --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit marfa:vN -l league_69189dd1-61c5-4ade-a554-39416eef19de"
