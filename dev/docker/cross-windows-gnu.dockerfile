# syntax=docker/dockerfile:1
# check=experimental=all
#
# Build image of the Windows target with the msvcrt C runtime
# (x86_64-pc-windows-gnu), which Windows 7 has. clang compiles for the target on
# the mingw-w64 sysroot, crt files, and libgcc of the crosstool-NG GCC 16 MinGW
# toolchain, and GNU ld of that toolchain links, so the archives call only the
# helpers of libgcc that the MinGW GCC of the consumers links, as in the TreeTime
# Windows 7 image. clang compiles and links for the build machine on the glibc
# 2.17 sysroot of a crosstool-NG GCC 16 toolchain.
FROM debian:13.7-slim@sha256:62bd423aeee912639ca8ee681c2b762cb3e25137e0a92b20be455898a9f034ad

SHELL ["bash", "-euxo", "pipefail", "-c"]

ARG CROSS_ARCH
ARG CROSS_COMPILE
ARG CROSS_COMPILE_UPPER
ARG CROSS_MINGW_TRIPLET
ARG CROSS_RUNNER

ENV HOST_TUPLE="x86_64-unknown-linux-gnu"
ENV CROSS_ARCH="${CROSS_ARCH}"
ENV CROSS_COMPILE="${CROSS_COMPILE}"
ENV CROSS_COMPILE_UPPER="${CROSS_COMPILE_UPPER}"
ENV CROSS_MINGW_TRIPLET="${CROSS_MINGW_TRIPLET}"
ENV CROSS_RUNNER="${CROSS_RUNNER}"

RUN set -euxo pipefail >/dev/null \
&& export DEBIAN_FRONTEND=noninteractive \
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
  sudo \
  tar \
  time \
  unzip \
  util-linux \
  wine64 \
  xz-utils \
  zstd \
>/dev/null \
&& apt-get clean autoclean >/dev/null \
&& apt-get autoremove --yes >/dev/null \
&& rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

COPY --link "dev/docker/files/distrust-compromised-roots" "/"
RUN /distrust-compromised-roots

COPY --link "dev/docker/files/fetch" "dev/docker/files/checksums" "/"

ENV LLVM_DIR="/opt/llvm"
ENV HOST_GCC_DIR="/opt/gcc-${HOST_TUPLE}"
ENV CROSS_GCC_DIR="/opt/gcc-${CROSS_MINGW_TRIPLET}"
COPY --link "dev/docker/files/install-llvm" "dev/docker/files/install-gcc-cross" "dev/docker/files/install-clang-target" "/"
RUN set -euxo pipefail >/dev/null \
&& /install-llvm "${LLVM_DIR}" \
&& /install-gcc-cross "${HOST_TUPLE}" "${HOST_GCC_DIR}" \
&& /install-clang-target "${LLVM_DIR}" "${HOST_TUPLE}" "${HOST_GCC_DIR}" \
&& /install-gcc-cross "${CROSS_MINGW_TRIPLET}" "${CROSS_GCC_DIR}" \
&& PATH="${CROSS_GCC_DIR}/bin:${PATH}" /install-clang-target "${LLVM_DIR}" "${CROSS_MINGW_TRIPLET}" "${CROSS_GCC_DIR}" \
&& rm /install-llvm /install-gcc-cross /install-clang-target

# clang compiles for the target on the sysroot, crt files, and libgcc of the
# MinGW GCC toolchain, and links with its GNU ld, which it finds on PATH. The
# configuration of the target names the sysroot, so the builds pass no
# --sysroot (CROSS_SYSROOT stays unset).
ENV PATH="${LLVM_DIR}/bin:${CROSS_GCC_DIR}/bin:${PATH}"
ENV TOOLCHAIN_RECORD_LLVM="${LLVM_DIR}/llvm.json"
ENV TOOLCHAIN_RECORD_TARGET="${CROSS_GCC_DIR}/toolchain.json"

ENV CC_${CROSS_COMPILE}="${LLVM_DIR}/bin/${CROSS_MINGW_TRIPLET}-clang"
ENV CXX_${CROSS_COMPILE}="${LLVM_DIR}/bin/${CROSS_MINGW_TRIPLET}-clang++"
ENV AR_${CROSS_COMPILE}="${LLVM_DIR}/bin/llvm-ar"
ENV NM_${CROSS_COMPILE}="${LLVM_DIR}/bin/llvm-nm"
ENV RANLIB_${CROSS_COMPILE}="${LLVM_DIR}/bin/llvm-ranlib"
ENV STRIP_${CROSS_COMPILE}="${LLVM_DIR}/bin/llvm-strip"
ENV OBJDUMP_${CROSS_COMPILE}="${LLVM_DIR}/bin/llvm-objdump"

ENV HOST_CC="${LLVM_DIR}/bin/${HOST_TUPLE}-clang"
ENV HOST_CXX="${LLVM_DIR}/bin/${HOST_TUPLE}-clang++"
ENV HOST_AR="${LLVM_DIR}/bin/llvm-ar"

ENV WINEARCH="win64"
ENV WINEDEBUG="err+all,err-winediag,err-ole,fixme-all"

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
