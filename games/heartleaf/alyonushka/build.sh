#!/bin/sh
# Build and (optionally) upload the Alyonushka policy.
#
# UPLOAD REQUIREMENT — --use-bedrock:
# Historically a heartleaf villager upload HAD to pass --use-bedrock or
# the bot quit at start-up and failed the round. Since heartleaf 0.2.0
# the game pod holds the Bedrock sidecar and plays every gnome from the
# uploaded soul, so the player pod makes no LLM calls and coolbot's
# README says the flag is no longer needed — but it is harmless, and
# dropping it is exactly what once failed rounds. Keep passing it.
set -e
cd "$(dirname "$0")/../../.."
docker build -t alyonushka:latest -f games/heartleaf/alyonushka/Dockerfile .
echo "upload with (note --use-bedrock, see header):"
echo "  uv --project ~/p/metta run coworld upload-policy alyonushka:latest \\"
echo "    --name alyonushka --run /bin/policy_player --use-bedrock"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit alyonushka:vN \\"
echo "    -l league_f831ba75-e81b-4796-b8c6-cd10be18c0bf"
