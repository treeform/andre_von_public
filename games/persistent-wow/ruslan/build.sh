#!/bin/sh
# Build and (optionally) upload the Ruslan policy.
# Command player: vendored andre-wow-walker:v82 — the exact submitted
# Persistent Wow champion lineage (reference player + kobold-apologist
# controller, persistent-wow-e30 commit b8b551f28f). No LLM seat, no
# USE_BEDROCK or other secret-envs — the league's game container owns
# the secret-backed replay/HMAC values. The engine is vendored ONCE
# under games/vanilla-wow/bova/vendor/ and this Dockerfile COPYs it
# (both builds run from the repo root, so the cross-dir COPY works).
# A first Persistent Wow submission includes the initial character
# preference (creates a character only for an empty account);
# replacement preserves the durable account.
set -e
cd "$(dirname "$0")/../../.."
docker build --platform linux/amd64 -t ruslan:latest \
  -f games/persistent-wow/ruslan/Dockerfile .
echo "upload with (ENTRYPOINT/CMD are baked in; --run mirrors them):"
echo "  uv --project ~/p/metta run coworld upload-policy ruslan:latest \\"
echo "    --name ruslan --run /usr/local/bin/wow-walker \\"
echo "    --run --scenario=coworld-session --run --bot=kobold-apologist"
echo "submit (only after XP verification, never --auto-champion):"
echo "  Persistent Wow:"
echo "  uv --project ~/p/metta run coworld submit ruslan:vN -l league_778f16b8-1247-488e-a993-b48d6928b137"
