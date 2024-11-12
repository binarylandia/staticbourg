# syntax=docker/dockerfile:1
# check=experimental=all
FROM debian:12.7

SHELL ["bash", "-euxo", "pipefail", "-c"]

ENV HOST_TUPLE_DEBIAN="x86_64-linux-gnu"
ENV HOST_TUPLE="x86_64-unknown-linux-gnu"

ARG CROSS_COMPILE
ARG CROSS_COMPILE_UPPER
ARG CROSS_APPLE_TRIPLET
ARG CROSS_GCC_TRIPLET

ENV CROSS_COMPILE="${CROSS_COMPILE}"
ENV CROSS_COMPILE_UPPER="${CROSS_COMPILE_UPPER}"
ENV CROSS_APPLE_TRIPLET="${CROSS_APPLE_TRIPLET}"
ENV CROSS_GCC_TRIPLET="${CROSS_GCC_TRIPLET}"

RUN set -euxo pipefail >/dev/null \
&& export DEBIAN_FRONTEND=noninteractive \
&& apt-get update -qq --yes \
&& apt-get install -qq --no-install-recommends --yes \
  autoconf \
  automake \
  autopoint \
  bash \
  bash-completion \
  bzip2 \
  ca-certificates \
  ccache \
  cmake \
  curl \
  file \
  git \
  gzip \
  libc6-dev \
  libstdc++6 \
  libtool \
  lsb-release \
  make \
  parallel \
  patch \
  pbzip2 \
  pigz \
  pixz \
  pkg-config \
  python3 \
  python3-pip \
  sudo \
  tar \
  time \
  unzip \
  util-linux \
  xz-utils \
  zstd \
>/dev/null \
&& rm -rf /var/lib/apt/lists/* \
&& apt-get clean autoclean >/dev/null \
&& apt-get autoremove --yes >/dev/null



ENV HOST_GCC_DIR="/usr/local"
ENV HOSTCC="${HOST_GCC_DIR}/bin/gcc"
ENV HOSTCXX="${HOST_GCC_DIR}/bin/g++"
ENV HOSTFC="${HOST_GCC_DIR}/bin/gfortran"
ENV LIBRARY_PATH="/usr/lib:/usr/lib64:/usr/local/lib:/usr/local/lib64:/usr/lib/${HOST_TUPLE_DEBIAN}"
ENV LD_LIBRARY_PATH="/usr/lib:/usr/lib64:/usr/local/lib:/usr/local/lib64:/usr/lib/${HOST_TUPLE_DEBIAN}"

COPY --link "dev/docker/files/install-gcc" "/"
RUN /install-gcc "${HOST_GCC_DIR}"

COPY --link "dev/docker/files/install-llvm" "/"
RUN /install-llvm

ENV OSX_CROSS_PATH="/opt/osxcross"
ENV OSXCROSS_MP_INC="1"
ENV MACOSX_DEPLOYMENT_TARGET="10.12"
ENV PATH="${OSX_CROSS_PATH}/bin:${PATH}"
ENV CROSS_SYSROOT="${OSX_CROSS_PATH}/SDK/MacOSX11.1.sdk"

ENV CC_${CROSS_COMPILE}="${OSX_CROSS_PATH}/bin/${CROSS_APPLE_TRIPLET}-clang"
ENV CXX_${CROSS_COMPILE}="${OSX_CROSS_PATH}/bin/${CROSS_APPLE_TRIPLET}-clang++"
ENV FC_${CROSS_COMPILE}="${OSX_CROSS_PATH}/bin/${CROSS_GCC_TRIPLET}-gfortran"
ENV AR_${CROSS_COMPILE}="${OSX_CROSS_PATH}/bin/${CROSS_APPLE_TRIPLET}-ar"
ENV AS_${CROSS_COMPILE}="${OSX_CROSS_PATH}/bin/${CROSS_APPLE_TRIPLET}-as"
ENV DSYMUTIL_${CROSS_COMPILE}="${OSX_CROSS_PATH}/bin/${CROSS_APPLE_TRIPLET}-dsymutil"
ENV LD_${CROSS_COMPILE}="${OSX_CROSS_PATH}/bin/${CROSS_APPLE_TRIPLET}-ld"
ENV LIBTOOL_${CROSS_COMPILE}="${OSX_CROSS_PATH}/bin/${CROSS_APPLE_TRIPLET}-libtool"
ENV LIPO_${CROSS_COMPILE}="${OSX_CROSS_PATH}/bin/${CROSS_APPLE_TRIPLET}-lipo"
ENV NM_${CROSS_COMPILE}="${OSX_CROSS_PATH}/bin/${CROSS_APPLE_TRIPLET}-nm"
ENV OBJDUMP_${CROSS_COMPILE}="${OSX_CROSS_PATH}/bin/${CROSS_APPLE_TRIPLET}-ObjectDump"
ENV OTOOL_${CROSS_COMPILE}="${OSX_CROSS_PATH}/bin/${CROSS_APPLE_TRIPLET}-otool"
ENV PKG_CONFIG_${CROSS_COMPILE}="${OSX_CROSS_PATH}/bin/${CROSS_APPLE_TRIPLET}-pkg-config"
ENV RANLIB_${CROSS_COMPILE}="${OSX_CROSS_PATH}/bin/${CROSS_APPLE_TRIPLET}-ranlib"
ENV STRIP_${CROSS_COMPILE}="${OSX_CROSS_PATH}/bin/${CROSS_APPLE_TRIPLET}-strip"

# HACK: resolve confusion between aarch64 and arm64 by adding both
ENV LIBRARY_PATH="${OSX_CROSS_PATH}/lib/gcc/${CROSS_APPLE_TRIPLET}/14.2.0:${OSX_CROSS_PATH}/lib/gcc/${CROSS_GCC_TRIPLET}/14.2.0:${OSX_CROSS_PATH}/MacOSX11.1.sdk/usr/lib:${LIBRARY_PATH}"
ENV LD_LIBRARY_PATH="${OSX_CROSS_PATH}/lib/gcc/${CROSS_APPLE_TRIPLET}/14.2.0:${OSX_CROSS_PATH}/lib/gcc/${CROSS_GCC_TRIPLET}/14.2.0:${OSX_CROSS_PATH}/MacOSX11.1.sdk/usr/lib:${LD_LIBRARY_PATH}"

COPY --link "dev/docker/files/install-osxcross" "/"
RUN /install-osxcross "${OSX_CROSS_PATH}"


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
