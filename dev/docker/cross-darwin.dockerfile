# syntax=docker/dockerfile:1
# check=experimental=all
#
# Build image of a macOS target. The osxcross wrappers of the llvm flavor compile
# and link for the target with clang and ld64.lld of LLVM 22, the macOS 11.1
# SDK, and compiler-rt. clang compiles and links for the build machine on the
# glibc 2.17 sysroot of a crosstool-NG GCC 16 toolchain. These are the
# toolchains of the TreeTime images that link the archives.
FROM debian:12.15-slim@sha256:7ff6ba31527b9e336162fa061746c366c4b2032f4d2cff2078bea43f78efe3f8

SHELL ["bash", "-euxo", "pipefail", "-c"]

ARG CROSS_COMPILE
ARG CROSS_COMPILE_UPPER
ARG CROSS_APPLE_TRIPLET
ARG CROSS_MACOS_DEPLOYMENT_TARGET

ENV HOST_TUPLE="x86_64-unknown-linux-gnu"
ENV CROSS_COMPILE="${CROSS_COMPILE}"
ENV CROSS_COMPILE_UPPER="${CROSS_COMPILE_UPPER}"
ENV CROSS_APPLE_TRIPLET="${CROSS_APPLE_TRIPLET}"

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
  xz-utils \
  zstd \
>/dev/null \
&& apt-get clean autoclean >/dev/null \
&& apt-get autoremove --yes >/dev/null \
&& rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

COPY --link "dev/docker/files/fetch" "dev/docker/files/checksums" "/"

ENV LLVM_DIR="/opt/llvm"
ENV HOST_GCC_DIR="/opt/gcc-${HOST_TUPLE}"
ENV OSX_CROSS_PATH="/opt/osxcross"
COPY --link "dev/docker/files/install-llvm" "dev/docker/files/install-gcc-cross" "dev/docker/files/install-clang-target" "dev/docker/files/install-osxcross" "/"
RUN set -euxo pipefail >/dev/null \
&& /install-llvm "${LLVM_DIR}" \
&& /install-gcc-cross "${HOST_TUPLE}" "${HOST_GCC_DIR}" \
&& /install-clang-target "${LLVM_DIR}" "${HOST_TUPLE}" "${HOST_GCC_DIR}" \
&& /install-osxcross "${OSX_CROSS_PATH}" "${LLVM_DIR}" \
&& rm /install-llvm /install-gcc-cross /install-clang-target /install-osxcross

ENV MACOSX_DEPLOYMENT_TARGET="${CROSS_MACOS_DEPLOYMENT_TARGET}"
ENV OSXCROSS_MP_INC="1"
ENV PATH="${OSX_CROSS_PATH}/bin:${LLVM_DIR}/bin:${PATH}"
ENV CROSS_SYSROOT="${OSX_CROSS_PATH}/SDK/MacOSX11.1.sdk"

ENV CC_${CROSS_COMPILE}="${OSX_CROSS_PATH}/bin/${CROSS_APPLE_TRIPLET}-clang"
ENV CXX_${CROSS_COMPILE}="${OSX_CROSS_PATH}/bin/${CROSS_APPLE_TRIPLET}-clang++"
ENV AR_${CROSS_COMPILE}="${OSX_CROSS_PATH}/bin/${CROSS_APPLE_TRIPLET}-ar"
ENV NM_${CROSS_COMPILE}="${OSX_CROSS_PATH}/bin/${CROSS_APPLE_TRIPLET}-nm"
ENV RANLIB_${CROSS_COMPILE}="${OSX_CROSS_PATH}/bin/${CROSS_APPLE_TRIPLET}-ranlib"
ENV STRIP_${CROSS_COMPILE}="${OSX_CROSS_PATH}/bin/${CROSS_APPLE_TRIPLET}-strip"
ENV OTOOL_${CROSS_COMPILE}="${OSX_CROSS_PATH}/bin/${CROSS_APPLE_TRIPLET}-otool"

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
