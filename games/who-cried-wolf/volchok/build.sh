#!/bin/sh
# Build and (optionally) upload the Volchok policy.
# Deterministic command player, NO secret-envs needed (no LLM seat).
set -e
cd "$(dirname "$0")/../../.."
docker build --platform linux/amd64 -t volchok:latest -f games/who-cried-wolf/volchok/Dockerfile .
echo "upload with:"
echo "  tools/auto_player upload-image volchok:latest volchok /bin/policy_player"
echo "submit (first entry only; later only after significant XP wins):"
echo "  tools/auto_player submit volchok:vN league_a10c10a8-46da-4f0f-bff6-4087c8dac619"
