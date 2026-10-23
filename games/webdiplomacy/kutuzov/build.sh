#!/bin/sh
# Build the image when an operator explicitly runs this script.
set -eu
cd "$(dirname "$0")/../../.."
docker build --platform linux/amd64 -t kutuzov:latest \
  -f games/webdiplomacy/kutuzov/Dockerfile .
echo "Upload separately after reviewing the image:"
echo "  nim r -d:ssl tools/auto_player.nim upload-image kutuzov:latest kutuzov \\"
echo "    --secret-env=COWORLD_LLM_ENABLED=true \\"
echo "    --secret-env=COWORLD_LLM_MODEL=openai/gpt-6.1-sol \\"
echo "    --secret-env=KUTUZOV_ECONOMY_MODEL=gpt-6-luna \\"
echo "    --secret-env=KUTUZOV_BUDGET_MODE=empirical \\"
echo "    --secret-env=KUTUZOV_TOOL_LOOP=true \\"
echo "    --secret-env=KUTUZOV_RESERVE_USD=0.10 \\"
echo "    --secret-env=KUTUZOV_MAX_PHASE_CALLS=12 \\"
echo "    --secret-env=KUTUZOV_MAX_PRESS_CALLS=1 \\"
echo "    --secret-env=KUTUZOV_MAX_OUTPUT_TOKENS=3000 \\"
echo "    -- /opt/.venv/bin/python -m players.launcher /opt/kutuzov"
echo "Run hosted XP before selecting a league or submitting this policy."
