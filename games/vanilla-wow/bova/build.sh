#!/bin/sh
# Build and (optionally) upload the Bova Korolevich policy.
# Command player: vendored andre-wow-walker:v82 lineage (reference
# player + kobold-apologist controller, persistent-wow-e30 commit
# b8b551f28f). No LLM seat, no USE_BEDROCK or other secret-envs — the
# league's game container owns the secret-backed replay/HMAC values.
# The engine is vendored under vendor/ and shared with
# games/persistent-wow/ruslan (its Dockerfile COPYs this vendor tree).
set -e
cd "$(dirname "$0")/../../.."
docker build --platform linux/amd64 -t bova:latest \
  -f games/vanilla-wow/bova/Dockerfile .
echo "upload with (ENTRYPOINT/CMD are baked in; --run mirrors them):"
echo "  uv --project ~/p/metta run coworld upload-policy bova:latest \\"
echo "    --name bova --run /usr/local/bin/wow-walker \\"
echo "    --run --scenario=coworld-session --run --bot=kobold-apologist"
echo "submit (only after XP verification, never --auto-champion):"
echo "  Arena Wow:"
echo "  uv --project ~/p/metta run coworld submit bova:vN -l league_55a25b77-5fe5-4fc7-aa37-c1ece4756e18"
echo "  Race Wow:"
echo "  uv --project ~/p/metta run coworld submit bova:vN -l league_0f38d762-930a-41d3-9979-1858dd52c1ae"
echo "  Dungeon Wow:"
echo "  uv --project ~/p/metta run coworld submit bova:vN -l league_3d05f6f9-d812-4123-a69d-4da0ff3ad8b0"
echo "  10x Wow:"
echo "  uv --project ~/p/metta run coworld submit bova:vN -l league_faf92aca-4edd-4591-923f-27b09af629bb"
