# syntax=docker/dockerfile:1
# check=experimental=all
FROM debian:12.7

SHELL ["bash", "-euxo", "pipefail", "-c"]

ENV HOST_TUPLE_DEBIAN="x86_64-linux-gnu"
ENV HOST_TUPLE="x86_64-unknown-linux-gnu"

ARG CROSS_ARCH_DEBIAN
ARG CROSS_ARCH
ARG CROSS_COMPILE
ARG CROSS_COMPILE_UPPER
ARG CROSS_GCC_TRIPLET
ARG CROSS_RUNNER

ENV HOST_TUPLE="x86_64-linux-gnu"
ENV CROSS_ARCH_DEBIAN="${CROSS_ARCH_DEBIAN}"
ENV CROSS_ARCH="${CROSS_ARCH}"
ENV CROSS_COMPILE="${CROSS_COMPILE}"
ENV CROSS_COMPILE_UPPER="${CROSS_COMPILE_UPPER}"
ENV CROSS_GCC_TRIPLET="${CROSS_GCC_TRIPLET}"
ENV CROSS_RUNNER="${CROSS_RUNNER}"

RUN set -euxo pipefail >/dev/null \
&& export DEBIAN_FRONTEND=noninteractive \
&& dpkg --add-architecture ${CROSS_ARCH_DEBIAN} \
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
&& if [[ "${CROSS_COMPILE}" =~ (linux) ]]; then apt-get install -qq --no-install-recommends --yes  \
  libc6:${CROSS_ARCH_DEBIAN} \
  qemu-user \
>/dev/null \
;fi \
&& if [[ "${CROSS_COMPILE}" =~ (mingw|windows) ]]; then apt-get install -qq --no-install-recommends --yes  \
  wine64 \
>/dev/null \
;fi \
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

ENV CROSS_GCC_DIR="/opt/gcc-${CROSS_GCC_TRIPLET}"
ENV PATH="${CROSS_GCC_DIR}/bin:${PATH}"
ENV CROSS_SYSROOT="${CROSS_GCC_DIR}/${CROSS_GCC_TRIPLET}/sysroot"
ENV CC_${CROSS_COMPILE}="${CROSS_GCC_DIR}/bin/${CROSS_GCC_TRIPLET}-gcc"
ENV CXX_${CROSS_COMPILE}="${CROSS_GCC_DIR}/bin/${CROSS_GCC_TRIPLET}-g++"
ENV FC_${CROSS_COMPILE}="${CROSS_GCC_DIR}/bin/${CROSS_GCC_TRIPLET}-gfortran"
ENV ADDR2LINE_${CROSS_COMPILE}="${CROSS_GCC_DIR}/bin/${CROSS_GCC_TRIPLET}-addr2line"
ENV AR_${CROSS_COMPILE}="${CROSS_GCC_DIR}/bin/${CROSS_GCC_TRIPLET}-gcc-ar"
ENV AS_${CROSS_COMPILE}="${CROSS_GCC_DIR}/bin/${CROSS_GCC_TRIPLET}-as"
ENV CPP_${CROSS_COMPILE}="${CROSS_GCC_DIR}/bin/${CROSS_GCC_TRIPLET}-cpp"
ENV ELFEDIT_${CROSS_COMPILE}="${CROSS_GCC_DIR}/bin/${CROSS_GCC_TRIPLET}-elfedit"
ENV LD_${CROSS_COMPILE}="${CROSS_GCC_DIR}/bin/${CROSS_GCC_TRIPLET}-ld"
ENV LDD_${CROSS_COMPILE}="${CROSS_GCC_DIR}/bin/${CROSS_GCC_TRIPLET}-ldd"
ENV NM_${CROSS_COMPILE}="${CROSS_GCC_DIR}/bin/${CROSS_GCC_TRIPLET}-gcc-nm"
ENV OBJCOPY_${CROSS_COMPILE}="${CROSS_GCC_DIR}/bin/${CROSS_GCC_TRIPLET}-objcopy"
ENV OBJDUMP_${CROSS_COMPILE}="${CROSS_GCC_DIR}/bin/${CROSS_GCC_TRIPLET}-objdump"
ENV RANLIB_${CROSS_COMPILE}="${CROSS_GCC_DIR}/bin/${CROSS_GCC_TRIPLET}-gcc-ranlib"
ENV READELF_${CROSS_COMPILE}="${CROSS_GCC_DIR}/bin/${CROSS_GCC_TRIPLET}-readelf"
ENV SIZE_${CROSS_COMPILE}="${CROSS_GCC_DIR}/bin/${CROSS_GCC_TRIPLET}-size"
ENV STRINGS_${CROSS_COMPILE}="${CROSS_GCC_DIR}/bin/${CROSS_GCC_TRIPLET}-strings"
ENV STRIP_${CROSS_COMPILE}="${CROSS_GCC_DIR}/bin/${CROSS_GCC_TRIPLET}-strip"

COPY --link "dev/docker/files/install-gcc-cross" "/"
RUN /install-gcc-cross "${CROSS_GCC_TRIPLET}" "${CROSS_GCC_DIR}"


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
