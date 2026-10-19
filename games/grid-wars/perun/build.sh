#!/bin/sh
# Build and (optionally) upload the Perun policy.
# Upload needs --secret-env USE_BEDROCK=true: without it the seat
# silently plays scripted (docs/readme.md).
set -e
cd "$(dirname "$0")/../../.."
docker build --platform linux/amd64 -t perun:latest \
  -f games/grid-wars/perun/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy perun:latest \\"
echo "    --name perun --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit perun:vN -l league_f07f6eeb-bdd2-49ec-82bd-a3fa2bb568e5"
