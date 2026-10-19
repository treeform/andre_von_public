# Ruslan — Persistent Wow policy. Build from the REPO ROOT:
#   docker build --platform linux/amd64 -t ruslan:latest \
#     -f games/persistent-wow/ruslan/Dockerfile .
#
# Vendored andre-wow-walker:v82 (coworld-vanilla-wow persistent-wow-e30,
# commit b8b551f28f) — the exact submitted Persistent Wow lineage. The
# engine tree and every nimby.lock dependency are vendored ONCE under
# games/vanilla-wow/bova/vendor/ and shared by both wow policies; this
# Dockerfile COPYs that tree (both builds run from the repo root, so the
# cross-dir COPY works). No --build-context, no SSH mounts, no nimby
# sync. Compile flags live in games/persistent-wow/ruslan/nim.cfg.

ARG NIMBY_VERSION=0.1.27
ARG NIM_VERSION=2.2.10
ARG COWORLD_NIM_PARALLEL_BUILD=8
ARG TARGETARCH

# Upstream streamed-asset image (public ECR, anonymous pull): the
# walker's client reads the sprite atlas next to the binary's asset dir.
FROM public.ecr.aws/q5f4m8t9/cogames@sha256:1c7f864504d5b52e5e4e67f6efeccce1ef8e8b12baec7be8db0c0a951a123471 AS wow_assets

FROM debian:bookworm-slim@sha256:7b140f374b289a7c2befc338f42ebe6441b7ea838a042bbd5acbfca6ec875818 AS walker_builder

ARG NIMBY_VERSION
ARG NIM_VERSION
ARG COWORLD_NIM_PARALLEL_BUILD
ARG TARGETARCH

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl gcc g++ libc6-dev libssl-dev \
    libx11-dev libxcursor-dev libxrandr-dev libxinerama-dev libxi-dev \
    libgl1-mesa-dev \
  && rm -rf /var/lib/apt/lists/*

ENV PATH="/root/.nimby/nim/bin:${PATH}"
RUN arch="${TARGETARCH:-}" \
  && if [ -z "${arch}" ]; then \
       case "$(dpkg --print-architecture)" in \
         amd64) arch=amd64 ;; \
         arm64) arch=arm64 ;; \
         *) arch="$(uname -m)" ;; \
       esac; \
     fi \
  && case "${arch}" in \
      amd64|x86_64) nimby_asset="nimby-Linux-X64" ;; \
      arm64|aarch64) nimby_asset="nimby-Linux-ARM64" ;; \
      *) echo "Unsupported Nimby target architecture: ${arch}" >&2; exit 1 ;; \
    esac \
  && curl -fsSL -o /usr/local/bin/nimby \
      "https://github.com/treeform/nimby/releases/download/${NIMBY_VERSION}/${nimby_asset}" \
  && chmod +x /usr/local/bin/nimby \
  && nimby use "${NIM_VERSION}"

# Reproduce the repo-relative layout so ruslan's nim.cfg relative paths
# (../../vanilla-wow/bova/vendor/...) resolve identically in the image
# and locally.
WORKDIR /work
COPY games/vanilla-wow/bova/vendor/ games/vanilla-wow/bova/vendor/
COPY games/persistent-wow/ruslan/ games/persistent-wow/ruslan/

RUN nim c \
  --parallelBuild:"${COWORLD_NIM_PARALLEL_BUILD}" \
  --nimcache:/tmp/nimcache-ruslan \
  -d:release \
  -o:/usr/local/bin/wow-walker \
  games/persistent-wow/ruslan/ruslan.nim

FROM debian:bookworm-slim@sha256:7b140f374b289a7c2befc338f42ebe6441b7ea838a042bbd5acbfca6ec875818

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    xvfb xauth \
    libgl1 libglx-mesa0 libgl1-mesa-dri \
    libx11-6 libxext6 libxrandr2 libxi6 libxcursor1 libxinerama1 \
    libssl3 \
  && rm -rf /var/lib/apt/lists/*

COPY --from=walker_builder /usr/local/bin/wow-walker /usr/local/bin/wow-walker
COPY --from=wow_assets \
  /opt/coworld-python/player/assets/atlas.png \
  /opt/coworld/player/assets/atlas.png

ENV LD_LIBRARY_PATH=/usr/local/lib
ENV LIBGL_ALWAYS_SOFTWARE=1
ENV GALLIUM_DRIVER=llvmpipe
ENV WOW_SDK_NIM_RUNTIME_DIR=/tmp/coworld-native-player

# The policy consumes the Coworld handoff in the canonical semantic
# runtime (no GUI, no Xvfb needed at startup; xvfb stays installed to
# match the upstream image).
ENTRYPOINT ["/usr/local/bin/wow-walker"]
CMD ["--scenario=coworld-session", "--bot=kobold-apologist"]
