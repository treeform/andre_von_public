# Mikula Selyaninovich — Agricogla policy (vendored terra champion).
# Build from the REPO ROOT:
#   docker build -t mikula:latest -f games/agricogla/mikula/Dockerfile .
# Mirrors ~/p/terra/Dockerfile: nimby Nim 2.2.4, whisky, and terra's
# release flags (useMalloc, opt:speed, stackTrace, threads, orc, ssl).
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
COPY games/agricogla/mikula/ .
RUN rm -f nim.cfg && nim c \
  -d:release \
  -d:useMalloc \
  -d:ssl \
  --opt:speed \
  --stackTrace:on \
  --threads:on \
  --mm:orc \
  --path:/workspace/whisky/src \
  --nimcache:/tmp/policy-nimcache \
  --out:policy_player \
  mikula.nim

FROM debian:bookworm-slim

RUN apt-get update && \
  apt-get install -y --no-install-recommends \
    ca-certificates \
    libssl3 && \
  rm -rf /var/lib/apt/lists/*

COPY --from=build /workspace/policy/policy_player /bin/policy_player

ENTRYPOINT ["/bin/policy_player"]
