#!/bin/sh
# Build and (optionally) upload the Ded Moroz policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays the reciprocator baseline (docs/policies.md).
set -e
cd "$(dirname "$0")/../../.."
docker build -t ded_moroz:latest -f games/gift-refinements/ded_moroz/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy ded_moroz:latest \\"
echo "    --name ded_moroz --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit ded_moroz:vN -l league_aa42c0da-031b-49b1-9524-e4acc85fd2f6"
