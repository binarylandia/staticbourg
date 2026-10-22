# syntax=docker/dockerfile:1
# check=experimental=all
#
# Build image of the wasm32-unknown-emscripten target: emcc compiles the
# libraries, the GCC of Debian compiles the helper programs that some builds run
# on the build machine, and Node runs emcc.
FROM debian:12.15-slim@sha256:7ff6ba31527b9e336162fa061746c366c4b2032f4d2cff2078bea43f78efe3f8

SHELL ["bash", "-euxo", "pipefail", "-c"]

ARG CROSS_COMPILE
ENV CROSS_COMPILE="${CROSS_COMPILE}"

RUN set -euxo pipefail >/dev/null \
&& export DEBIAN_FRONTEND=noninteractive \
&& apt-get update -qq \
&& apt-get install --no-install-recommends --yes -qq \
  autoconf \
  automake \
  bash \
  bzip2 \
  ca-certificates \
  cmake \
  curl \
  file \
  g++ \
  gcc \
  git \
  gzip \
  jq \
  libc6-dev \
  libtool \
  make \
  parallel \
  patch \
  pbzip2 \
  pigz \
  pixz \
  pkg-config \
  python3 \
  sudo \
  tar \
  time \
  util-linux \
  xz-utils \
  zstd \
>/dev/null \
&& apt-get clean autoclean >/dev/null \
&& apt-get autoremove --yes >/dev/null \
&& rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

ARG NODE_VERSION="24.21.0"
ARG NODE_SHA256="fd8e59d5a511510f6a298afb548f18c7d2b1be404d8b4a27d94fbe49f56cb2d6"
ARG NODE_DIR="/opt/node"
RUN set -euxo pipefail >/dev/null \
&& curl -fsSLo "/tmp/node.tar.xz" "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" \
&& printf '%s  %s\n' "${NODE_SHA256}" "/tmp/node.tar.xz" | sha256sum --check --quiet \
&& mkdir -p "${NODE_DIR}" \
&& tar -xJf "/tmp/node.tar.xz" --strip-components=1 -C "${NODE_DIR}" \
&& rm "/tmp/node.tar.xz" \
&& ln -s "${NODE_DIR}/bin/node" "/usr/local/bin/node" \
&& node --version

ARG EMSCRIPTEN_VERSION="6.0.10"
ARG EMSCRIPTEN_BUILD="666337b525e673e769121856d175f6f52b8ead64"
ARG EMSCRIPTEN_SHA256="a51dd2829bdf725d268974728e032533b106ea01cb482a62288ec12627a7abbe"
ARG EMSCRIPTEN_DIR="/opt/emscripten"

# Emscripten: the archive that `emsdk install <version>` downloads; the build id
# is the entry of the version in emscripten-releases-tags.json of emsdk. The
# configuration names the LLVM and Binaryen of the archive. Only the emcc front
# end goes on PATH. The cache holds the prebuilt system libraries and stays
# writable for its lock and sanity files, because the container runs as the
# host user. toolchain.json records the URL and sha256 of the archive for the
# build records of the archives.
ENV EMSCRIPTEN_DIR="${EMSCRIPTEN_DIR}"
ENV PATH="${EMSCRIPTEN_DIR}/emscripten:${PATH}"
RUN set -euxo pipefail >/dev/null \
&& curl -fsSLo "/tmp/wasm-binaries.tar.xz" "https://storage.googleapis.com/webassembly/emscripten-releases-builds/linux/${EMSCRIPTEN_BUILD}/wasm-binaries.tar.xz" \
&& printf '%s  %s\n' "${EMSCRIPTEN_SHA256}" "/tmp/wasm-binaries.tar.xz" | sha256sum --check --quiet \
&& mkdir -p "${EMSCRIPTEN_DIR}" \
&& tar -xJf "/tmp/wasm-binaries.tar.xz" --strip-components=1 -C "${EMSCRIPTEN_DIR}" \
&& rm "/tmp/wasm-binaries.tar.xz" \
&& printf "LLVM_ROOT = '%s/bin'\nBINARYEN_ROOT = '%s'\n" "${EMSCRIPTEN_DIR}" "${EMSCRIPTEN_DIR}" >"${EMSCRIPTEN_DIR}/emscripten/.emscripten" \
&& grep -qxF "${EMSCRIPTEN_VERSION}-git" "${EMSCRIPTEN_DIR}/emscripten/emscripten-version.txt" \
&& emcc --version \
&& jq -n --arg url "https://storage.googleapis.com/webassembly/emscripten-releases-builds/linux/${EMSCRIPTEN_BUILD}/wasm-binaries.tar.xz" --arg sha256 "${EMSCRIPTEN_SHA256}" '{url: $url, sha256: $sha256}' >"${EMSCRIPTEN_DIR}/toolchain.json" \
&& chmod -R a+rwX "${EMSCRIPTEN_DIR}/emscripten/cache"

ENV CROSS_SYSROOT="${EMSCRIPTEN_DIR}/emscripten/cache/sysroot"
ENV TOOLCHAIN_RECORD_TARGET="${EMSCRIPTEN_DIR}/toolchain.json"
ENV CC_wasm32-unknown-emscripten="emcc"
ENV CXX_wasm32-unknown-emscripten="em++"
ENV AR_wasm32-unknown-emscripten="emar"
ENV NM_wasm32-unknown-emscripten="emnm"
ENV RANLIB_wasm32-unknown-emscripten="emranlib"
ENV STRIP_wasm32-unknown-emscripten="emstrip"

ARG USER=user
ARG GROUP=user
ARG UID
ARG GID

ENV USER=$USER
ENV GROUP=$GROUP
ENV UID=$UID
ENV GID=$GID
ENV TERM="xterm-256color"
ENV HOME="/home/${USER}"

COPY --link "dev/docker/files/create-user" "/"
RUN /create-user

USER ${USER}
