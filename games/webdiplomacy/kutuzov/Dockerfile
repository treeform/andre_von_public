# Build from the repository root with games/webdiplomacy/kutuzov/build.sh.
ARG PLAYER_IMAGE=public.ecr.aws/q5f4m8t9/cogames@sha256:8b1779858fd1eb1c6394dad4a5e7c41131a1d9eec3a6c266e8a6bc7dbed8efd0
FROM debian:bookworm-slim AS build

RUN apt-get update && \
  apt-get install -y --no-install-recommends \
    build-essential ca-certificates curl git && \
  rm -rf /var/lib/apt/lists/*

RUN case "$(dpkg --print-architecture)" in \
    amd64) release=nimby-Linux-X64 ;; \
    arm64) release=nimby-Linux-ARM64 ;; \
    *) echo "Unsupported build architecture."; exit 1 ;; \
  esac && \
  curl -fsSL \
    "https://github.com/treeform/nimby/releases/download/0.1.26/$release" \
    -o /usr/local/bin/nimby && \
  chmod +x /usr/local/bin/nimby && \
  nimby use 2.2.4

ENV PATH="/root/.nimby/nim/bin:$PATH"
WORKDIR /workspace/kutuzov
COPY games/webdiplomacy/kutuzov/nimby.lock ./
RUN nimby --global -V sync nimby.lock

COPY games/webdiplomacy/kutuzov/ ./
RUN for package in /root/.nimby/pkgs/*; do \
    if [ -d "$package/src" ]; then \
      printf '\n--path:"%s/src"\n' "$package"; \
    else \
      printf '\n--path:"%s"\n' "$package"; \
    fi; \
  done >> nim.cfg
RUN nim c \
  -d:release \
  --opt:speed \
  --stackTrace:on \
  --lineTrace:on \
  --nimcache:/tmp/kutuzov-nimcache \
  --out:/opt/kutuzov \
  kutuzov.nim

# This known player image supplies the official WebSocket lifecycle launcher.
FROM ${PLAYER_IMAGE}
RUN apt-get update && \
  apt-get install -y --no-install-recommends ca-certificates libcurl4 && \
  rm -rf /var/lib/apt/lists/*
COPY --from=build /opt/kutuzov /opt/kutuzov
COPY games/webdiplomacy/kutuzov/tools/kutuzov_artifacts.py /opt/players/kutuzov_artifacts.py
COPY games/webdiplomacy/kutuzov/tools/install_artifact_hook.py /tmp/install_artifact_hook.py
RUN /opt/.venv/bin/python /tmp/install_artifact_hook.py /opt/players/press.py /opt/players/launcher.py && \
  rm /tmp/install_artifact_hook.py
ENV KUTUZOV_LOG_DIR=/tmp/kutuzov/logs
CMD ["/opt/kutuzov"]
