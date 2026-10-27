# syntax=docker/dockerfile:1
# check=experimental=all
#
# Build image of a Linux target. clang and lld of LLVM 23 compile and link for
# the target and for the build machine, each on the sysroot, crt files, libgcc,
# and libstdc++ of a crosstool-NG GCC 16 toolchain: glibc 2.17 for the gnu
# targets and the build machine, musl 1.2.6 for the musl targets. These are the
# toolchains of the TreeTime images that link the archives.
FROM debian:13.7-slim@sha256:62bd423aeee912639ca8ee681c2b762cb3e25137e0a92b20be455898a9f034ad

SHELL ["bash", "-euxo", "pipefail", "-c"]

ARG CROSS_ARCH_DEBIAN
ARG CROSS_ARCH
ARG CROSS_COMPILE
ARG CROSS_COMPILE_UPPER
ARG CROSS_RUNNER

ENV HOST_TUPLE="x86_64-unknown-linux-gnu"
ENV CROSS_ARCH_DEBIAN="${CROSS_ARCH_DEBIAN}"
ENV CROSS_ARCH="${CROSS_ARCH}"
ENV CROSS_COMPILE="${CROSS_COMPILE}"
ENV CROSS_COMPILE_UPPER="${CROSS_COMPILE_UPPER}"
ENV CROSS_RUNNER="${CROSS_RUNNER}"

RUN set -euxo pipefail >/dev/null \
&& export DEBIAN_FRONTEND=noninteractive \
&& dpkg --add-architecture "${CROSS_ARCH_DEBIAN}" \
&& apt-get update -qq \
&& apt-get install --no-install-recommends --yes -qq \
  autoconf \
  automake \
  autopoint \
  bash \
  bzip2 \
  ca-certificates \
  ccache \
  cmake \
  curl \
  file \
  git \
  gzip \
  jq \
  "libc6:${CROSS_ARCH_DEBIAN}" \
  libtool \
  make \
  parallel \
  patch \
  pbzip2 \
  perl \
  pigz \
  pixz \
  pkg-config \
  python3 \
  qemu-user \
  sudo \
  tar \
  time \
  unzip \
  util-linux \
  xz-utils \
  zstd \
>/dev/null \
&& apt-get clean autoclean >/dev/null \
&& apt-get autoremove --yes >/dev/null \
&& rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

COPY --link "dev/docker/files/distrust-compromised-roots" "/"
RUN /distrust-compromised-roots

COPY --link "dev/docker/files/fetch" "dev/docker/files/checksums" "/"

# The target and the build machine get one GCC toolchain each, the same one when
# the target is x86_64-unknown-linux-gnu.
ENV LLVM_DIR="/opt/llvm"
ENV HOST_GCC_DIR="/opt/gcc-${HOST_TUPLE}"
ENV CROSS_GCC_DIR="/opt/gcc-${CROSS_COMPILE}"
COPY --link "dev/docker/files/install-llvm" "dev/docker/files/install-gcc-cross" "dev/docker/files/install-clang-target" "/"
RUN set -euxo pipefail >/dev/null \
&& /install-llvm "${LLVM_DIR}" \
&& /install-gcc-cross "${HOST_TUPLE}" "${HOST_GCC_DIR}" \
&& /install-clang-target "${LLVM_DIR}" "${HOST_TUPLE}" "${HOST_GCC_DIR}" \
&& if [ "${CROSS_COMPILE}" != "${HOST_TUPLE}" ]; then \
  /install-gcc-cross "${CROSS_COMPILE}" "${CROSS_GCC_DIR}" \
  && /install-clang-target "${LLVM_DIR}" "${CROSS_COMPILE}" "${CROSS_GCC_DIR}"; \
fi \
&& rm /install-llvm /install-gcc-cross /install-clang-target

ENV PATH="${LLVM_DIR}/bin:${PATH}"
ENV CROSS_SYSROOT="${CROSS_GCC_DIR}/${CROSS_COMPILE}/sysroot"
ENV TOOLCHAIN_RECORD_LLVM="${LLVM_DIR}/llvm.json"
ENV TOOLCHAIN_RECORD_TARGET="${CROSS_GCC_DIR}/toolchain.json"

ENV CC_${CROSS_COMPILE}="${LLVM_DIR}/bin/${CROSS_COMPILE}-clang"
ENV CXX_${CROSS_COMPILE}="${LLVM_DIR}/bin/${CROSS_COMPILE}-clang++"
ENV AR_${CROSS_COMPILE}="${LLVM_DIR}/bin/llvm-ar"
ENV NM_${CROSS_COMPILE}="${LLVM_DIR}/bin/llvm-nm"
ENV RANLIB_${CROSS_COMPILE}="${LLVM_DIR}/bin/llvm-ranlib"
ENV STRIP_${CROSS_COMPILE}="${LLVM_DIR}/bin/llvm-strip"
ENV LDD_${CROSS_COMPILE}="${CROSS_GCC_DIR}/bin/${CROSS_COMPILE}-ldd"
ENV OBJDUMP_${CROSS_COMPILE}="${CROSS_GCC_DIR}/bin/${CROSS_COMPILE}-objdump"
ENV STRINGS_${CROSS_COMPILE}="${CROSS_GCC_DIR}/bin/${CROSS_COMPILE}-strings"

ENV HOST_CC="${LLVM_DIR}/bin/${HOST_TUPLE}-clang"
ENV HOST_CXX="${LLVM_DIR}/bin/${HOST_TUPLE}-clang++"
ENV HOST_AR="${LLVM_DIR}/bin/llvm-ar"

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
