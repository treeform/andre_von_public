# Buyan — nmmo policy. Build from the REPO ROOT:
#   docker build -t buyan:latest -f games/nmmo/buyan/Dockerfile .
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

# Network weights, picked by BUYAN_NET:
#   legacy   the unchanged public MMONet weights, pinned to the coworld source
#            commit (byte-identical to
#            sims/nmmo/vendor/upstream/resources/nmmo3/nmmo3_weights.bin).
#   puffer5  nmmo3_1024x4.bin from the PufferLib 5.0 release bundle
#            (puffer5_models.zip); buyan asks for obs=clean with it.
ARG BUYAN_NET=legacy
RUN if [ "$BUYAN_NET" = "puffer5" ]; then \
    apt-get update && apt-get install -y --no-install-recommends unzip && \
    curl -fsSL -o /tmp/puffer5_models.zip \
https://github.com/PufferAI/PufferLib/releases/download/5.0-experiments/puffer5_models.zip \
    && unzip -p /tmp/puffer5_models.zip puffer5_models/nmmo3_1024x4.bin \
      > /workspace/nmmo3_weights.bin \
    && rm /tmp/puffer5_models.zip \
    && echo "99090dc7e33d92c6dba02278911069aa6787edd556abbab017beff7ab389793f  /workspace/nmmo3_weights.bin" \
    | sha256sum -c - ; \
  else \
    curl -fsSL -o /workspace/nmmo3_weights.bin \
https://raw.githubusercontent.com/Metta-AI/cogame-nmmo/96d4ce5a2d279dfb37f252366fa6209645c79a0c/vendor/upstream/resources/nmmo3/nmmo3_weights.bin \
    && echo "2bb4a521d2f744e23525baa16a074eb4bc88f1b26b5ad54d7fd571df89887da5  /workspace/nmmo3_weights.bin" \
    | sha256sum -c - ; \
  fi

WORKDIR /workspace/policy
COPY games/nmmo/buyan/buyan.nim games/nmmo/buyan/mmonet.nim \
  games/nmmo/buyan/guard.nim games/nmmo/buyan/scripted.nim ./
RUN nim c \
  -d:release \
  --opt:speed \
  --stackTrace:on \
  --path:/workspace/whisky/src \
  --path:/workspace/policy \
  --nimcache:/tmp/policy-nimcache \
  --out:policy_player \
  buyan.nim

FROM debian:bookworm-slim

RUN apt-get update && \
  apt-get install -y --no-install-recommends ca-certificates && \
  rm -rf /var/lib/apt/lists/*

COPY --from=build /workspace/policy/policy_player /bin/policy_player
COPY --from=build /workspace/nmmo3_weights.bin /policy/nmmo3_weights.bin
ENV BUYAN_WEIGHTS=/policy/nmmo3_weights.bin
# Experiment knobs: the defaults reproduce the champion build; a trial
# passes --build-arg and logs the value in ideas.md.
ARG BUYAN_TEMPERATURE=1
ENV BUYAN_TEMPERATURE=$BUYAN_TEMPERATURE
ARG BUYAN_GUARD=off
ENV BUYAN_GUARD=$BUYAN_GUARD
ARG BUYAN_STALL=0
ENV BUYAN_STALL=$BUYAN_STALL
ARG BUYAN_ENGINE=mmonet
ENV BUYAN_ENGINE=$BUYAN_ENGINE

ENTRYPOINT ["/bin/policy_player"]
