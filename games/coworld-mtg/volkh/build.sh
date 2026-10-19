#!/bin/sh
# Build and (optionally) upload the Volkh Vseslavevich policy.
# Pure scripted command player: NO secret-envs needed (no LLM seat).
set -e
cd "$(dirname "$0")/../../.."
docker build -t volkh:latest -f games/coworld-mtg/volkh/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy volkh:latest \\"
echo "    --name volkh --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit volkh:vN -l league_dddaa300-2cbd-4ce9-8362-73b9c57ed88d"
