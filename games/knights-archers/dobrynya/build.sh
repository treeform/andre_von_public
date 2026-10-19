#!/bin/sh
# Build and (optionally) upload the Dobrynya Nikitich policy.
# Default is scripted phalanx: no Bedrock flag required. LLM override
# (empty PLAYER_SCRIPTED) still needs --secret-env USE_BEDROCK=true.
set -e
cd "$(dirname "$0")/../../.."
docker build -t dobrynya:latest -f games/knights-archers/dobrynya/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy dobrynya:latest \\"
echo "    --name dobrynya --run /bin/policy_player --secret-env USE_BEDROCK=true"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit dobrynya:vN -l league_362e5211-3bdc-40f4-968e-c00c8f812bfe"
