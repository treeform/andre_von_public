# Kikimora — Crewrift policy (vendored truecrew bot). Build from the REPO ROOT:
#   docker build --platform linux/amd64 -t kikimora:latest -f games/crewrift/kikimora/Dockerfile .
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

# The bot compiles against the crewrift sim sources; pin the commit the
# vendored truecrew bot was developed against (notsus-optimizer branch).
RUN git clone https://github.com/Metta-AI/coworld-crewrift \
    /workspace/coworld-crewrift && \
  git -C /workspace/coworld-crewrift \
    checkout 8fa2822067cfe9faf212de17f0058f9e3f058b0a

# The lock pins the same package commits (bitworld, pixie, pathy,
# whisky, ...) the crewrift repo builds against.
WORKDIR /workspace/policy
COPY games/crewrift/kikimora/nimby.lock .
RUN nimby --global -V sync nimby.lock

COPY games/crewrift/kikimora/ .
# The checked-in nim.cfg points at this machine's local packages;
# rebuild it from the synced global packages plus the crewrift clone.
RUN printf -- '--threads:on\n--mm:orc\n--define:ssl\n' > nim.cfg && \
  echo '--path:"/workspace/coworld-crewrift/src"' >> nim.cfg && \
  for p in /root/.nimby/pkgs/*; do \
    if [ -d "$p/src" ]; then echo "--path:\"$p/src\""; \
    else echo "--path:\"$p\""; fi; \
  done >> nim.cfg
RUN nim c \
  -d:release \
  -d:botHeadless \
  -d:useMalloc \
  --opt:speed \
  --stackTrace:on \
  --nimcache:/tmp/policy-nimcache \
  --out:policy_player \
  kikimora.nim

FROM debian:bookworm-slim

# libcurl4 backs the curly/Bedrock voting-chat client; ca-certificates
# cover both it and whisky's wss connection.
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
    ca-certificates \
    libcurl4 && \
  rm -rf /var/lib/apt/lists/*

WORKDIR /workspace/coworld-crewrift
COPY --from=build /workspace/policy/policy_player /bin/policy_player

ENTRYPOINT ["/bin/policy_player"]
