#!/bin/sh
# Build and (optionally) upload the Kikimora policy (vendored truecrew).
# Command player over the bitworld sprite protocol. The voting LLM chat
# activates only when a Bedrock key env is present; upload with
# --secret-env BEDROCK_KEY=... (or AWS_BEARER_TOKEN_BEDROCK) to enable it.
set -e
cd "$(dirname "$0")/../../.."
docker build --platform linux/amd64 -t kikimora:latest \
  -f games/crewrift/kikimora/Dockerfile .
echo "upload with:"
echo "  uv --project ~/p/metta run coworld upload-policy kikimora:latest \\"
echo "    --name kikimora --run /bin/policy_player"
echo "submit (only after XP verification, never --auto-champion):"
echo "  # Crewrift (classic) league:"
echo "  uv --project ~/p/metta run coworld submit kikimora:vN -l league_605ff338-0a2e-4e62-aeda-559df9a9198f"
echo "  # Crewrift Prime league (different scenarios; verify via XP first):"
echo "  uv --project ~/p/metta run coworld submit kikimora:vN -l league_a12f5172-0907-4d04-8bcb-ca02f5360e3a"
