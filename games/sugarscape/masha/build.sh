#!/bin/sh
# Build and (optionally) upload the Masha policy.
# Command player: submits one declarative SugarLang ruleset, so NO
# USE_BEDROCK or other secret-envs are required.
set -e
cd "$(dirname "$0")/../../.."
docker build -t masha:latest -f games/sugarscape/masha/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy masha:latest \\"
echo "    --name masha --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  # Solo ladder:"
echo "  uv --project ~/p/metta run coworld submit masha:vN -l league_620a74a7-eb1f-4386-b386-0e7246be4eb6"
echo "  # Duos:"
echo "  uv --project ~/p/metta run coworld submit masha:vN -l league_d5b48dfe-5e08-499f-80f1-63f14720c50c"
echo "  # Commonwealth (qualifier gates result.rulesets_identical):"
echo "  uv --project ~/p/metta run coworld submit masha:vN -l league_dac00450-027a-45e6-9f6b-c9bda7ddd61d"
