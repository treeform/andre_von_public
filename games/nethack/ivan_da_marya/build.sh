#!/bin/sh
# Build and (optionally) upload the Ivan Da Marya policy.
# No USE_BEDROCK secret-env needed: the anthropic_api_key coworld secret
# is injected into the GAME pod, which makes every decision — the seat
# only registers its prompt (docs/protocol_player.md).
set -e
cd "$(dirname "$0")/../../.."
docker build -t ivan_da_marya:latest -f games/nethack/ivan_da_marya/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy ivan_da_marya:latest \\"
echo "    --name ivan_da_marya --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit ivan_da_marya:vN -l league_462e0339-0d14-4f35-8bb2-ad882f4b0224"
