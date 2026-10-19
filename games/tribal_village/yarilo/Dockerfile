# Yarilo — Tribal Village policy. Build from the REPO ROOT:
#   docker build -t yarilo:latest -f games/tribal_village/yarilo/Dockerfile .
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
  git -C /workspace/whisky checkout 774f3274f5dc2c738f36e19d22291eca344b9f8e && \
  git clone https://github.com/treeform/vmath /workspace/vmath && \
  git -C /workspace/vmath checkout 2.0.1 && \
  git clone https://github.com/treeform/chroma /workspace/chroma && \
  git -C /workspace/chroma checkout v1.0.0

WORKDIR /workspace/policy
COPY games/tribal_village/yarilo/ .
RUN rm -f nim.cfg && nim c \
  -d:release \
  -d:useMalloc \
  --opt:speed \
  --stackTrace:on \
  --path:/workspace/whisky/src \
  --path:/workspace/vmath/src \
  --path:/workspace/chroma/src \
  --path:/workspace/policy \
  --nimcache:/tmp/policy-nimcache \
  --out:policy_player \
  yarilo.nim

FROM debian:bookworm-slim

RUN apt-get update && \
  apt-get install -y --no-install-recommends ca-certificates && \
  rm -rf /var/lib/apt/lists/*

COPY --from=build /workspace/policy/policy_player /bin/policy_player

ENTRYPOINT ["/bin/policy_player"]
