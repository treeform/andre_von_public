# Zvezdochet — Planet Wars policy. Build from the REPO ROOT:
#   docker build -t zvezdochet:latest -f games/planet_wars/zvezdochet/Dockerfile .
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

# Sprite pixel data arrives snappy-compressed; pin matches the
# coworld-planet-wars nimby.lock.
RUN git clone https://github.com/guzba/supersnappy /workspace/supersnappy && \
  git -C /workspace/supersnappy checkout ff8fe2bffefc1f4edc15deb20d921f600babb8c4

WORKDIR /workspace/policy
COPY tools/coworld_client.nim .
COPY games/planet_wars/zvezdochet/ .
RUN rm -f nim.cfg && nim c \
  -d:release \
  --opt:speed \
  --stackTrace:on \
  --path:/workspace/whisky/src \
  --path:/workspace/supersnappy/src \
  --path:/workspace/policy \
  --nimcache:/tmp/policy-nimcache \
  --out:policy_player \
  zvezdochet.nim

FROM debian:bookworm-slim

RUN apt-get update && \
  apt-get install -y --no-install-recommends ca-certificates libssl3 && \
  rm -rf /var/lib/apt/lists/*

COPY --from=build /workspace/policy/policy_player /bin/policy_player

ENTRYPOINT ["/bin/policy_player"]
