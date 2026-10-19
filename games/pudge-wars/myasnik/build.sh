#!/bin/sh
# Build and (optionally) upload the Myasnik policy.
# Command player: no LLM, no secret-envs required (do not set USE_BEDROCK).
set -e
cd "$(dirname "$0")/../../.."
docker build -t myasnik:latest -f games/pudge-wars/myasnik/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy myasnik:latest \\"
echo "    --name myasnik --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  uv --project ~/p/metta run coworld submit myasnik:vN -l league_84ab9f1e-5fb8-4b62-a3ac-e49026bd12d0"
