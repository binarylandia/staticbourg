#!/usr/bin/env bash
set -euo pipefail

export JOBS="${JOBS:=$(($(nproc --all) + 2))}"
export NICE="nice -14 ionice -c2 -n3"

# The targets that every task builds for, and the tasks that also build for
# WebAssembly. dev/cross/all builds the native targets unless --target names
# others, and dev/release publishes only the full set: every task for every
# native target, and the WebAssembly tasks for WASM_TARGET.
# shellcheck disable=SC2034 # used by the scripts that source this file
NATIVE_TARGETS=(
  "x86_64-unknown-linux-gnu"
  "x86_64-unknown-linux-musl"
  "aarch64-unknown-linux-gnu"
  "aarch64-unknown-linux-musl"
  "x86_64-pc-windows-gnu"
  "x86_64-pc-windows-gnullvm"
  "aarch64-pc-windows-gnullvm"
  "aarch64-apple-darwin"
  "x86_64-apple-darwin"
)
# shellcheck disable=SC2034 # used by the scripts that source this file
WASM_TARGET="wasm32-unknown-emscripten"
# shellcheck disable=SC2034 # used by the scripts that source this file
WASM_TASKS=("lzma" "zstd")

function print_color() {
  local color_code="${1}"
  local message="${2}"
  if [[ -z "${FORCE_COLOR:-}" && (-n "${NO_COLOR:-}" || "${TERM:-}" == "dumb" || $(tput colors 2>/dev/null) -lt 8) ]]; then
    echo "${message}"
  else
    echo -e "\e[38;5;${color_code}m${message}\e[0m"
  fi
}
export -f print_color

function err() {
  print_color 1 "[ERR] $0: $1"
}
export -f err

function warn() {
  print_color 3 "[WARN] $0: $1"
}
export -f warn

function info() {
  print_color 6 "[INFO] $0: $1"
}
export -f info

function debug() {
  print_color 8 "[DEBUG] $0: $1"
}
export -f debug

function log() {
  tee -a "${1}" |
    GREP_COLORS='mt=01;31' grep --line-buffered --color=always -iE "\b(err|error|fail|can not|cannot|can't|unable|critical|fatal|reject|deny|denied|terminat|abort|panic|fault|invalid|undefined symbol|not found|)\b" |
    GREP_COLORS='mt=01;33' grep --line-buffered --color=always -iE "\b(warn|warning|caution|alert|notice|)\b" |
    GREP_COLORS='mt=01;36' grep --line-buffered --color=always -iE "\b(note|info|status|detail|)\b"
}
export -f log

function datetime_safe() {
  TZ=UTC date -u '+%Y-%m-%d_%H-%M-%S'
}
export -f datetime_safe

function datetime_ms_safe() {
  TZ=UTC date -u '+%Y-%m-%d_%H-%M-%S_%3NZ'
}
export -f datetime_ms_safe

function nicely() {
  print_color 8 "+${*:-}" >&2
  ${NICE} bash -c "${*:-}"
}
export -f nicely

function fake_tty() {
  script -qefc bash -c "$*" /dev/null
}

# shellcheck disable=SC2155
function file_hash() {
  local paths=("$@")
  local uid=$(id -u)
  local gid=$(id -g)
  local user=$(id -un)
  local group=$(id -gn)
  echo -n "$uid $gid $user $group" | cat - "${paths[@]}" | md5sum | cut -f 1 -d " " | cut -c1-7
}
export -f file_hash

function abspath() {
  readlink -m "${1:?}"
}
export -f abspath

function here() {
  cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")"
  pwd -P
}
export -f here

function project_root() {
  abspath "$(here)/../.."
}
export -f project_root

function get_build_dir() {
  local target="${1:-}"
  abspath "$(project_root)/.build/docker${target:+"-${target}"}"
}
export -f get_build_dir

function get_cache_dir() {
  local target="${1:-}"
  abspath "$(project_root)/.cache/docker${target:+"-${target}"}"
}
export -f get_cache_dir

function get_test_dir() {
  local target="${1:-}"
  abspath "$(get_build_dir "${target}")/test"
}
export -f get_test_dir

function get_out_dir() {
  abspath "$(project_root)/.out"
}
export -f get_out_dir

function get_bin_dir() {
  local target="${1:-}"
  abspath "$(get_build_dir "${target}")/${target}/release"
}
export -f get_bin_dir

function guess_ext() {
  local target="${1:-}"
  if [[ "$target" =~ (mingw|windows) ]]; then
    echo ".exe"
  fi
}
export -f guess_ext

function get_full_bin_path() {
  local bin="${1:?}"
  local target="${2:-}"
  ext="$(guess_ext "${target}")"
  echo "$(get_bin_dir "${target}")/${bin}${ext}"
}
export -f get_full_bin_path

function get_final_bin_path() {
  local bin="${1:?}"
  local target="${2:-}"
  ext="$(guess_ext "${target}")"
  echo "$(get_out_dir)/${bin}${target:+-${target}}${ext}"
}
export -f get_final_bin_path

function load_env_maybe() {
  local env_file="${1:-}"
  # shellcheck disable=SC2046
  [ -n "${env_file}" ] && export $(grep -v '^#' .env | xargs)
}
export -f load_env_maybe

function load_env() {
  local env_file="${1:?}"
  if ! [ -r "${env_file}" ]; then
    err "unable to load env file: '${env_file}'" >&2
    exit 1
  fi
  load_env_maybe "${env_file}"
}
export -f load_env

function package_xz() {
  local input_dir="${1}"
  local output_basename="${2}"
  mkdir -p "$(dirname "${output_basename}")"
  nicely "find '${input_dir}' -printf '%P\\n' | tar --posix --no-recursion -cf '${output_basename}.tar.xz' -C '${input_dir}' --files-from=- --use-compress-program='pixz -p $(nproc) -5'"
}
export -f package_xz

function package_gz() {
  local input_dir="${1}"
  local output_basename="${2}"
  mkdir -p "$(dirname "${output_basename}")"
  nicely "find '${input_dir}' -printf '%P\\n' | tar --posix --no-recursion -cf '${output_basename}.tar.gz' -C '${input_dir}' --files-from=- --use-compress-program='pigz -p $(nproc) -7'"
}
export -f package_gz

function package_zst() {
  local input_dir="${1}"
  local output_basename="${2}"
  mkdir -p "$(dirname "${output_basename}")"
  nicely "find '${input_dir}' -printf '%P\\n' | tar --posix --no-recursion -cf '${output_basename}.tar.zst' -C '${input_dir}' --files-from=- --use-compress-program='zstdmt -q -T$(nproc) -7'"
}
export -f package_zst

function package_all() {
  local input_dir="${1}"
  local output_basename="${2}"

  parallel ::: \
    "package_xz '${input_dir}' '${output_basename}'" \
    "package_gz '${input_dir}' '${output_basename}'" \
    "package_zst '${input_dir}' '${output_basename}'"
}
export -f package_all

function fetch_tarball() {
  local tarball_url="${1}"
  local dest_dir="${2}"
  shift 2
  local tar_params=("$@")
  mkdir -p "${dest_dir}"
  case "${tarball_url}" in
  *.tar.gz | *.tgz) nicely "curl -fsSL '${tarball_url}' | tar -xf - --posix -C '${dest_dir}' ${tar_params[*]} --use-compress-program='pigz -dc -p ${JOBS}'" ;;
  *.tar.xz | *.txz) nicely "curl -fsSL '${tarball_url}' | tar -xf - --posix -C '${dest_dir}' ${tar_params[*]} --use-compress-program='pixz -dc -p ${JOBS}'" ;;
  *.tar.zst | *.tzst) nicely "curl -fsSL '${tarball_url}' | tar -xf - --posix -C '${dest_dir}' ${tar_params[*]} --use-compress-program='pzstd -dc -p ${JOBS}'" ;;
  *.tar.bz2 | *.tbz | *.tb2) nicely "curl -fsSL '${tarball_url}' | tar -xf - --posix -C '${dest_dir}' ${tar_params[*]} --use-compress-program='pbzip2 -dc -p ${JOBS}'" ;;
  *)
    echo "Unsupported file format" >&2
    return 1
    ;;
  esac
}
export -f fetch_tarball

# Download a source tarball, verify it against its sha256 in a checksums file
# (lines of "<sha256>  <file name>", keyed by the file name of the URL), and
# unpack it into a directory without its top-level folder. A missing or
# different checksum fails.
function fetch_verified_tarball() {
  local url="${1:?url}"
  local checksums="${2:?checksums file}"
  local dest_dir="${3:?destination}"
  local expected actual tmp
  expected="$(recorded_sha256 "${url}" "${checksums}")"
  tmp="$(mktemp)"
  curl -fsSL --retry 3 -o "${tmp}" "${url}"
  actual="$(sha256sum "${tmp}" | cut -d' ' -f1)"
  if [[ "${actual}" != "${expected}" ]]; then
    rm -f "${tmp}"
    err "Checksum mismatch for ${url}: expected ${expected}, got ${actual}"
    return 1
  fi
  rm -rf "${dest_dir}"
  mkdir -p "${dest_dir}"
  tar -xf "${tmp}" -C "${dest_dir}" --strip-components=1
  rm -f "${tmp}"
}
export -f fetch_verified_tarball

# Print the sha256 of a download that a checksums file records (lines of
# "<sha256>  <file name>", keyed by the file name of the URL), or fail.
function recorded_sha256() {
  local url="${1:?url}"
  local checksums="${2:?checksums file}"
  local name="${url##*/}"
  local sha256
  sha256="$(awk -v name="${name}" '$2 == name { print $1 }' "${checksums}")"
  if [[ -z "${sha256}" ]]; then
    err "No checksum recorded for ${name} in ${checksums}" >&2
    return 1
  fi
  printf '%s\n' "${sha256}"
}
export -f recorded_sha256

# Name of a target in package names. Emscripten gives no ABI guarantee between
# versions, so a WebAssembly library links only with the Emscripten version that
# built it, and its package name carries that version
# (wasm32-unknown-emscripten.6.0.10).
function package_target_name() {
  local target="${1:?target}"
  if [[ "${target}" == wasm32-*-emscripten ]]; then
    local version
    version="$(<"${EMSCRIPTEN_DIR:?}/emscripten/emscripten-version.txt")"
    printf '%s.%s\n' "${target}" "${version%-git}"
  else
    printf '%s\n' "${target}"
  fi
}
export -f package_target_name

# Record the Emscripten version in a WebAssembly package, so a consumer can
# check it against the Emscripten it links with.
function install_target_info() {
  local install_dir="${1:?install dir}"
  if [[ "${CROSS_COMPILE:?}" == wasm32-*-emscripten ]]; then
    install -D -m 0644 "${EMSCRIPTEN_DIR:?}/emscripten/emscripten-version.txt" "${install_dir}/share/emscripten-version.txt"
  fi
}
export -f install_target_info

# Package an installed library with its build record, as
# <out dir>/<library>-<version>-static-<target>-<build time>.tar.{xz,gz,zst}.
# The build record goes into the archives as share/staticbourg/build.json and
# next to them as <archive name>.json, which dev/release collects into the
# manifest of a release. It holds the library fields given here and the
# toolchain fields of BUILD_RECORD (toolchain_record):
#   name, task, library, version, source, source_sha256: the archive name
#     without the extension, the task (tasks/<task>/build), and the library with
#     its source tarball
#   kind: "native", or "wasm" for WebAssembly
#   target, compiler: the target, and the first line of `$CC --version`
#   llvm: the binarylandia/build_llvm release of the image (native only)
#   target_toolchain: {url, sha256} of the toolchain archive of the target (GCC,
#     osxcross, llvm-mingw, or Emscripten)
#   cflags: the C flags that the task passes to the build of the library
#     (CFLAGS when it packages the library), which its build system can extend
#   cpu_flags: the CPU baseline flags among them (native only)
#   macosx_deployment_target, win32_winnt: macOS and msvcrt Windows only
#   emscripten: the Emscripten version (wasm only)
#   dockerfile, dockerfile_sha256: the image file of the build and its sha256
#   build_commit, build_dirty, build_time: the commit of the checkout, whether
#     the checkout had uncommitted or untracked files, and the build time
#   files: the archive files
function package_with_record() {
  local install_dir="${1:?install dir}"
  local out_dir="${2:?out dir}"
  local library="${3:?library}"
  local version="${4:?version}"
  local source="${5:?source url}"
  local source_sha256="${6:?source sha256}"
  local name
  name="${library}-${version}-static-$(package_target_name "${CROSS_COMPILE:?}")-${BUILD_TIME:?}"

  install_target_info "${install_dir}"
  local record="${install_dir}/share/staticbourg/build.json"
  mkdir -p "$(dirname "${record}")" "${out_dir}"
  jq -n \
    --arg name "${name}" \
    --arg task "${TASK:?}" \
    --arg library "${library}" \
    --arg version "${version}" \
    --arg source "${source}" \
    --arg source_sha256 "${source_sha256}" \
    --argjson toolchain "${BUILD_RECORD:?}" \
    --arg cflags "${CFLAGS:?}" \
    '{name: $name, task: $task, library: $library, version: $version, source: $source, source_sha256: $source_sha256}
      + $toolchain
      + {cflags: $cflags}
      + {files: ["tar.xz", "tar.gz", "tar.zst"] | map("\($name).\(.)")}' \
    >"${record}"

  package_all "${install_dir}" "${out_dir}/${name}"
  cp "${record}" "${out_dir}/${name}.json"
}
export -f package_with_record

# Print the toolchain fields of the build records of a build as JSON (see
# package_with_record), from the compiler and CPU flags of the build, the download
# records of the image (TOOLCHAIN_RECORD_LLVM, TOOLCHAIN_RECORD_TARGET, written
# by the installers in dev/docker/files), and the provenance that
# dev/docker/run passes in.
function toolchain_record() {
  local cpu_flags="${1:-}"
  local win32_winnt="${2:-}"
  local compiler
  compiler="$(${CC:?} --version)"
  compiler="${compiler%%$'\n'*}"

  local kind="native"
  local emscripten=""
  if [[ "${CROSS_COMPILE:?}" == wasm32-*-emscripten ]]; then
    kind="wasm"
    emscripten="$(<"${EMSCRIPTEN_DIR:?}/emscripten/emscripten-version.txt")"
    emscripten="${emscripten%-git}"
    cpu_flags=""
  fi

  local llvm="null"
  if [[ -n "${TOOLCHAIN_RECORD_LLVM:-}" ]]; then
    llvm="$(<"${TOOLCHAIN_RECORD_LLVM}")"
  fi
  local target_toolchain="null"
  if [[ -n "${TOOLCHAIN_RECORD_TARGET:-}" ]]; then
    target_toolchain="$(<"${TOOLCHAIN_RECORD_TARGET}")"
  fi

  # A GitHub release download URL is
  # https://github.com/<owner>/<repo>/releases/download/<tag>/<asset>.
  jq -n \
    --arg kind "${kind}" \
    --arg target "${CROSS_COMPILE}" \
    --arg compiler "${compiler}" \
    --argjson llvm "${llvm}" \
    --argjson target_toolchain "${target_toolchain}" \
    --arg cpu_flags "${cpu_flags}" \
    --arg macosx_deployment_target "${MACOSX_DEPLOYMENT_TARGET:-}" \
    --arg win32_winnt "${win32_winnt}" \
    --arg emscripten "${emscripten}" \
    --arg dockerfile "${DOCKERFILE:?}" \
    --arg dockerfile_sha256 "${DOCKERFILE_SHA256:?}" \
    --arg build_commit "${BUILD_COMMIT:?}" \
    --arg build_dirty "${BUILD_DIRTY:?}" \
    --arg build_time "${BUILD_TIME:?}" \
    '{
      kind: $kind,
      target: $target,
      compiler: $compiler,
      llvm: (if $llvm then $llvm.url | split("/") | .[-2] else null end),
      target_toolchain: $target_toolchain,
      cpu_flags: $cpu_flags,
      macosx_deployment_target: $macosx_deployment_target,
      win32_winnt: $win32_winnt,
      emscripten: $emscripten,
      dockerfile: $dockerfile,
      dockerfile_sha256: $dockerfile_sha256,
      build_commit: $build_commit,
      build_dirty: ($build_dirty == "true"),
      build_time: $build_time
    } | with_entries(select(.value != null and .value != ""))'
}
export -f toolchain_record

# Print the words of a string separated by single spaces.
function join_words() {
  local words
  read -ra words <<<"${1:-}"
  printf '%s\n' "${words[*]}"
}
export -f join_words

# Print the host triplet of autoconf for a target: the MinGW triplet for the
# Windows targets, the target itself otherwise.
function autoconf_host() {
  local target="${1:?target}"
  case "${target}" in
  *-pc-windows-gnu | *-pc-windows-gnullvm)
    printf '%s-w64-mingw32\n' "${target%%-*}"
    ;;
  *)
    printf '%s\n' "${target}"
    ;;
  esac
}
export -f autoconf_host

# Run the CMake configure step of a source directory into a build directory for
# CROSS_COMPILE, with the further CMake arguments given. CMake then configures
# for the target system (WIN32, APPLE, UNIX, and the libraries of that system)
# and not for the Linux host: WebAssembly through emcmake and the toolchain file
# of Emscripten, the other targets through cmake_toolchain_file.
function cmake_configure() {
  local src_dir="${1:?source dir}"
  local build_dir="${2:?build dir}"
  shift 2
  if [[ "${CROSS_COMPILE:?}" == wasm32-*-emscripten ]]; then
    nicely emcmake cmake -S "${src_dir}" -B "${build_dir}" "$@"
  else
    # CMake looks for a relative toolchain file in the build and source
    # directories, not in the working directory.
    local toolchain_file
    toolchain_file="$(abspath "${build_dir}")/toolchain.cmake"
    mkdir -p "${build_dir}"
    cmake_toolchain_file >"${toolchain_file}" || return
    nicely cmake -S "${src_dir}" -B "${build_dir}" -DCMAKE_TOOLCHAIN_FILE="${toolchain_file}" "$@"
  fi
}
export -f cmake_configure

# Print a CMake toolchain file for CROSS_COMPILE from the tools that
# dev/cross/build takes from the image (CC, CXX, AR, RANLIB) and the sysroot of
# the image (CROSS_SYSROOT). It names the system and processor as CMake reports
# them on the target, and restricts the search for libraries, headers, and
# packages to the target's root: the sysroot, or for MinGW the directory of the
# Windows import libraries of the compiler.
function cmake_toolchain_file() {
  local system processor
  case "${CROSS_COMPILE:?}" in
  x86_64-*-linux-*) system="Linux" processor="x86_64" ;;
  aarch64-*-linux-*) system="Linux" processor="aarch64" ;;
  x86_64-apple-darwin) system="Darwin" processor="x86_64" ;;
  aarch64-apple-darwin) system="Darwin" processor="arm64" ;;
  x86_64-pc-windows-*) system="Windows" processor="AMD64" ;;
  aarch64-pc-windows-*) system="Windows" processor="ARM64" ;;
  *)
    err "No CMake system known for ${CROSS_COMPILE}" >&2
    return 1
    ;;
  esac

  local root="${CROSS_SYSROOT:-}"
  if [[ "${system}" == "Windows" ]]; then
    local kernel32
    kernel32="$(${CC:?} -print-file-name=libkernel32.a)"
    if [[ "${kernel32}" != /* ]]; then
      err "${CC} finds no libkernel32.a for ${CROSS_COMPILE}" >&2
      return 1
    fi
    root="$(abspath "$(dirname "${kernel32}")/..")"
  fi
  : "${root:?"No target root for ${CROSS_COMPILE}: the image sets no CROSS_SYSROOT"}"

  printf 'set(CMAKE_SYSTEM_NAME "%s")\n' "${system}"
  printf 'set(CMAKE_SYSTEM_PROCESSOR "%s")\n' "${processor}"
  printf 'set(CMAKE_C_COMPILER "%s")\n' "${CC:?}"
  if [[ -n "${CXX:-}" ]]; then
    printf 'set(CMAKE_CXX_COMPILER "%s")\n' "${CXX}"
  fi
  printf 'set(CMAKE_AR "%s")\n' "${AR:?}"
  printf 'set(CMAKE_RANLIB "%s")\n' "${RANLIB:?}"
  case "${system}" in
  Linux)
    printf 'set(CMAKE_SYSROOT "%s")\n' "${root}"
    ;;
  Darwin)
    printf 'set(CMAKE_OSX_SYSROOT "%s")\n' "${root}"
    printf 'set(CMAKE_OSX_DEPLOYMENT_TARGET "%s")\n' "${MACOSX_DEPLOYMENT_TARGET:?}"
    ;;
  Windows)
    # The resource compiler of the MinGW toolchain, next to its C compiler.
    printf 'set(CMAKE_RC_COMPILER "%s")\n' "${CC%-*}-windres"
    ;;
  esac
  printf 'set(CMAKE_FIND_ROOT_PATH "%s")\n' "${root}"
  printf 'set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)\n'
  printf 'set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)\n'
  printf 'set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)\n'
  printf 'set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)\n'
}
export -f cmake_toolchain_file

# Print the names of the tasks (tasks/<name>/build) of a checkout, sorted.
function task_names() {
  local root="${1:?project root}"
  find "${root}/tasks" -mindepth 2 -maxdepth 2 -type f -name "build" -printf '%h\n' | sed 's|.*/||' | LC_ALL=C sort
}
export -f task_names

function getenv_cross() {
  local varname="${1:?}"
  local target="${2:-${CROSS_COMPILE:?}}"
  printenv "${varname^^}_${target}"
}
export -f getenv_cross

function random_string() {
  head /dev/urandom | tr -dc A-Za-z0-9 | head -c "${1:-16}"
}
export -f random_string
