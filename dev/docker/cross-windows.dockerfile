# syntax=docker/dockerfile:1
# check=experimental=all
#
# Build image of a Windows target with the Universal C Runtime
# (*-pc-windows-gnullvm). The llvm-mingw toolchain of LLVM 22 compiles and links
# for the target: clang and lld on the static mingw-w64 sysroot with UCRT,
# compiler-rt, and libunwind. clang compiles and links for the build machine on
# the glibc 2.17 sysroot of a crosstool-NG GCC 16 toolchain. These are the
# toolchains of the TreeTime images that link the archives.
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
COPY --link "dev/docker/files/install-llvm" "dev/docker/files/install-gcc-cross" "dev/docker/files/install-clang-target" "/"
RUN set -euxo pipefail >/dev/null \
&& /install-llvm "${LLVM_DIR}" --mingw \
&& /install-gcc-cross "${HOST_TUPLE}" "${HOST_GCC_DIR}" \
&& /install-clang-target "${LLVM_DIR}" "${HOST_TUPLE}" "${HOST_GCC_DIR}" \
&& rm /install-llvm /install-gcc-cross /install-clang-target

# The <triple>-clang drivers name the sysroot in their configuration files, so
# the builds pass no --sysroot (CROSS_SYSROOT stays unset).
ENV PATH="${LLVM_DIR}/bin:${PATH}"

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
