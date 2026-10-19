#!/bin/sh
# Build and (optionally) upload the Munchausen policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays scripted (tools/policy_conventions.md).
set -e
cd "$(dirname "$0")/../../.."
docker build -t munchausen:latest -f games/liars-dice/munchausen/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy munchausen:latest \\"
echo "    --name munchausen --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit munchausen:vN -l league_3aa78ed0-6a0e-466f-8666-521631b1124e"
