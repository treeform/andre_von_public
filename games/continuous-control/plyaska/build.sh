#!/bin/sh
# Build and (optionally) upload the Plyaska policy.
# NO secret-envs needed: every gait decision is made in the GAME pod,
# where the anthropic_api_key coworld secret is injected
# (docs/protocol_player.md) — the player pod makes no model call.
set -e
cd "$(dirname "$0")/../../.."
docker build -t plyaska:latest -f games/continuous-control/plyaska/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy plyaska:latest \\"
echo "    --name plyaska --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit plyaska:vN -l league_62a1e77b-c464-41ba-90df-702fc0d9d3db"
