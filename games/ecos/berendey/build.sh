#!/bin/sh
# Build and (optionally) upload the Berendey policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays scripted (docs/policies.md).
set -e
cd "$(dirname "$0")/../../.."
docker build -t berendey:latest -f games/ecos/berendey/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy berendey:latest \\"
echo "    --name berendey --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit berendey:vN -l league_60071522-0ef6-4ad3-b6e3-76651490c3fd"
