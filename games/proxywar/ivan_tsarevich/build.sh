#!/bin/sh
# Build and (optionally) upload the Ivan Tsarevich policy. Command
# player: no LLM seat, so no USE_BEDROCK secret-env is needed. The
# binary defaults to the V98 champion profile; pass
# `--run --profile=<name>` after the binary to field another arm.
set -e
cd "$(dirname "$0")/../../.."
docker build --platform linux/amd64 -t ivan_tsarevich:latest \
  -f games/proxywar/ivan_tsarevich/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy ivan_tsarevich:latest \\"
echo "    --name ivan_tsarevich --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit ivan_tsarevich:vN -l league_cb60d526-ecfd-4836-ab3a-81fc6cf7dc42"
