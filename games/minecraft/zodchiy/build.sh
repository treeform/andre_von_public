#!/bin/sh
# Build and (optionally) upload the Zodchiy policy.
# Secret-envs: none required — the GAME container holds the
# anthropic_api_key (docs/protocol_player.md: every primitive is
# computed inside the game container) and the prompt is compiled into
# the binary. If a league round ever shows the seat silently playing
# miner, add --secret-env USE_BEDROCK=true (the grf-football precedent).
set -e
cd "$(dirname "$0")/../../.."
docker build -t zodchiy:latest -f games/minecraft/zodchiy/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy zodchiy:latest \\"
echo "    --name zodchiy --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit zodchiy:vN -l league_390fe9da-f2a6-4001-93df-e08cc2788846"
