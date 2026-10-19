#!/bin/sh
# Build and (optionally) upload the Solovei Razboinik policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays scripted.
set -e
cd "$(dirname "$0")/../../.."
docker build -t solovei:latest -f games/gridlock/solovei/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy solovei:latest \\"
echo "    --name solovei --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit solovei:vN -l league_4c0f039e-3a99-48ad-9d72-c3f85a110ea8"
