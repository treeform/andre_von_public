#!/bin/sh
# Build and (optionally) upload the Kolobok Jr policy.
# NO secret-envs needed: every tactical order is made in the GAME pod,
# whose src/bodies/llm.nim holds the Bedrock/Anthropic transport and the
# anthropic_api_key secret (docs/readme.md) — the player pod makes no
# model call.
set -e
cd "$(dirname "$0")/../../.."
docker build -t kolobok_jr:latest -f games/physics-bodies/kolobok_jr/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy kolobok_jr:latest \\"
echo "    --name kolobok_jr --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit kolobok_jr:vN -l league_6fe36e5b-1b03-44f4-864e-8b5408d639ca"
