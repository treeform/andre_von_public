#!/bin/sh
# Build and (optionally) upload the Dubynya policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays the match baseline (docs/readme.md).
set -e
cd "$(dirname "$0")/../../.."
docker build -t dubynya:latest -f games/goofspiel-oshi-zumo/dubynya/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy dubynya:latest \\"
echo "    --name dubynya --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit dubynya:vN -l league_af4bfc41-a775-4d89-94eb-194bb5c74f97"
