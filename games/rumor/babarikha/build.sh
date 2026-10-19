#!/bin/sh
# Build and (optionally) upload the babarikha policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays scripted (league LLM seats, see tools/policy_conventions.md).
set -e
cd "$(dirname "$0")/../../.."
docker build -t babarikha:latest -f games/rumor/babarikha/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy babarikha:latest \\"
echo "    --name babarikha --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit babarikha:vN -l league_21909e9d-0b13-4750-afec-f8a4213c03a7"
