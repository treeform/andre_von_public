#!/bin/sh
# Build and (optionally) upload the Chichikov policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays scripted (tools/policy_conventions.md).
set -e
cd "$(dirname "$0")/../../.."
docker build -t chichikov:latest -f games/ledger/chichikov/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy chichikov:latest \\"
echo "    --name chichikov --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit chichikov:vN -l league_1ad5ff34-7cf7-4940-9ef2-b7690a4bf5aa"
