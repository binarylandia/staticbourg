# syntax=docker/dockerfile:1
# check=experimental=all
#
# Build image of the Windows target with the msvcrt C runtime
# (x86_64-pc-windows-gnu), which Windows 7 has. The crosstool-NG GCC 16 MinGW
# toolchain compiles and links for the target, as in the TreeTime Windows 7
# image that links the archives. clang compiles and links for the build machine
# on the glibc 2.17 sysroot of a crosstool-NG GCC 16 toolchain.
FROM debian:12.15-slim@sha256:7ff6ba31527b9e336162fa061746c366c4b2032f4d2cff2078bea43f78efe3f8

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
&& rm /install-llvm /install-gcc-cross /install-clang-target

# The GCC driver uses the sysroot that it was configured with, so the builds pass
# no --sysroot (CROSS_SYSROOT stays unset).
ENV PATH="${LLVM_DIR}/bin:${CROSS_GCC_DIR}/bin:${PATH}"

ENV CC_${CROSS_COMPILE}="${CROSS_GCC_DIR}/bin/${CROSS_MINGW_TRIPLET}-gcc"
ENV CXX_${CROSS_COMPILE}="${CROSS_GCC_DIR}/bin/${CROSS_MINGW_TRIPLET}-g++"
ENV AR_${CROSS_COMPILE}="${CROSS_GCC_DIR}/bin/${CROSS_MINGW_TRIPLET}-ar"
ENV NM_${CROSS_COMPILE}="${CROSS_GCC_DIR}/bin/${CROSS_MINGW_TRIPLET}-nm"
ENV RANLIB_${CROSS_COMPILE}="${CROSS_GCC_DIR}/bin/${CROSS_MINGW_TRIPLET}-ranlib"
ENV STRIP_${CROSS_COMPILE}="${CROSS_GCC_DIR}/bin/${CROSS_MINGW_TRIPLET}-strip"
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
