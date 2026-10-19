#!/bin/sh
# Build and (optionally) upload the boyan policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays scripted (league LLM seats, see tools/policy_conventions.md).
set -e
cd "$(dirname "$0")/../../.."
docker build -t boyan:latest -f games/parley/boyan/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy boyan:latest \\"
echo "    --name boyan --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit boyan:vN -l league_d5171da5-7f96-4b70-9421-d675b698e160"
