# Alyonushka — Heartleaf policy. Build from the REPO ROOT:
#   docker build -t alyonushka:latest -f games/heartleaf/alyonushka/Dockerfile .
# The binary is a thin soul uploader (see alyonushka.nim); the game pod
# plays the gnome from soul.md and runs the LLM harness itself.
FROM debian:bookworm-slim AS build

RUN apt-get update && \
  apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git && \
  rm -rf /var/lib/apt/lists/*

RUN if [ "$(dpkg --print-architecture)" = "amd64" ]; then \
    curl -fsSL \
      -o /usr/local/bin/nimby \
https://github.com/treeform/nimby/releases/download/0.1.26/nimby-Linux-X64; \
  elif [ "$(dpkg --print-architecture)" = "arm64" ]; then \
    curl -fsSL \
      -o /usr/local/bin/nimby \
https://github.com/treeform/nimby/releases/download/0.1.26/nimby-Linux-ARM64; \
  else \
    echo "unsupported arch: $(dpkg --print-architecture)" && exit 1; \
  fi && \
  chmod +x /usr/local/bin/nimby && \
  nimby use 2.2.4

ENV PATH="/root/.nimby/nim/bin:$PATH"

RUN git clone https://github.com/treeform/whisky /workspace/whisky && \
  git -C /workspace/whisky checkout 774f3274f5dc2c738f36e19d22291eca344b9f8e

WORKDIR /workspace/policy
COPY games/heartleaf/alyonushka/ .
RUN nim c \
  -d:release \
  --opt:speed \
  --stackTrace:on \
  --path:/workspace/whisky/src \
  --path:/workspace/policy \
  --nimcache:/tmp/policy-nimcache \
  --out:policy_player \
  alyonushka.nim

FROM debian:bookworm-slim

RUN apt-get update && \
  apt-get install -y --no-install-recommends ca-certificates && \
  rm -rf /var/lib/apt/lists/*

COPY --from=build /workspace/policy/policy_player /bin/policy_player
# The soul also ships as a plain file (embedded copy is identical), so an
# operator can swap it without a recompile via HEARTLEAF_SOUL_PATH.
COPY --from=build /workspace/policy/soul.md /soul.md
ENV HEARTLEAF_SOUL_PATH=/soul.md

ENTRYPOINT ["/bin/policy_player"]
