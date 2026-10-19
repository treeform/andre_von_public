# Ivan Tsarevich — Proxy War policy. Build from the REPO ROOT:
#   docker build -t ivan_tsarevich:latest -f games/proxywar/ivan_tsarevich/Dockerfile .
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

# The lock pins the same package commits ~/p/proxywar builds against.
WORKDIR /workspace/policy
COPY games/proxywar/ivan_tsarevich/nimby.lock .
RUN nimby --global sync nimby.lock

# PROXYWAR EXCEPTION to the repo's debian-slim rule: this game's dominant
# failure mode is `player_never_started` (120 s connect window), and the
# 85 MB debian image measurably forfeited seats (v2 mean 0.076 vs musl
# kutuzov:v98's 0.259 over the same 14 rounds). kutuzov has run this musl
# static build for months with no memory issues, so musl is proven safe
# HERE. Statically linked against musl so the runtime image can be `scratch`.
# The league's dominant failure mode is `player_never_started` — the
# platform gives a player 120 s to connect, and a policy that misses that
# window fails the round for every seat. A scratch image keeps the pull
# small; the bot opens one websocket and speaks JSON.
RUN apt-get update && \
  apt-get install -y --no-install-recommends musl-tools && \
  rm -rf /var/lib/apt/lists/*

COPY games/proxywar/ivan_tsarevich/ .
# The checked-in nim.cfg points at this machine's local packages;
# rebuild it from the synced global packages instead.
RUN printf -- '--mm:orc\n--threads:off\n' > nim.cfg && \
  for p in /root/.nimby/pkgs/*; do \
    if [ -d "$p/src" ]; then echo "--path:\"$p/src\""; \
    else echo "--path:\"$p\""; fi; \
  done >> nim.cfg
RUN nim c -d:release --opt:speed --stackTrace:on \
    --cc:gcc --gcc.exe:musl-gcc --gcc.linkerexe:musl-gcc \
    --passL:-static \
    --nimcache:/tmp/policy-nimcache \
    --out:policy_player \
    ivan_tsarevich.nim && \
  /workspace/policy/policy_player 2>&1 | grep -q "COWORLD_PLAYER_WS_URL is required"

# Run stage: nothing but the binary.
FROM scratch

COPY --from=build /workspace/policy/policy_player /bin/policy_player

CMD ["/bin/policy_player"]
