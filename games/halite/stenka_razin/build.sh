#!/bin/sh
# Build and (optionally) upload the Stepan Razin policy.
# No secret-envs needed: this is a pure scripted command player — the
# seat itself answers every observe frame, no LLM anywhere. Optional
# --secret-env PLAYER_SCRIPTED=corsair switches to the raider constants.
set -e
cd "$(dirname "$0")/../../.."
docker build -t stenka_razin:latest -f games/halite/stenka_razin/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy stenka_razin:latest \\"
echo "    --name stenka_razin --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit stenka_razin:vN -l league_82571537-04b2-4611-8200-59349283a022"
