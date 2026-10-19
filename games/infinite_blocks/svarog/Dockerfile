# Svarog — Infinite Blocks policy. Build from the REPO ROOT:
#   docker build -t svarog:latest -f games/infinite_blocks/svarog/Dockerfile .
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

# The policy dir vendors every dependency (whisky, supersnappy), so no
# clones are needed.
WORKDIR /workspace/policy
COPY games/infinite_blocks/svarog/ .
RUN nim c \
  -d:release \
  --opt:speed \
  --stackTrace:on \
  --threads:on \
  --path:/workspace/policy \
  --nimcache:/tmp/policy-nimcache \
  --out:policy_player \
  svarog.nim

FROM debian:bookworm-slim

RUN apt-get update && \
  apt-get install -y --no-install-recommends ca-certificates && \
  rm -rf /var/lib/apt/lists/*

COPY --from=build /workspace/policy/policy_player /bin/policy_player

ENTRYPOINT ["/bin/policy_player"]
