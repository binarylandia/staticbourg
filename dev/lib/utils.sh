#!/usr/bin/env bash
set -euo pipefail

export JOBS="${JOBS:=$(($(nproc --all) + 2))}"
export NICE="nice -14 ionice -c2 -n3"

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
  [[ "$target" =~ (mingw|windows) ]] && echo ".exe"
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
  nicely "find '${input_dir}' -printf '%P\\n' | tar --posix -cf '${output_basename}.tar.xz' -C '${input_dir}' --files-from=- --use-compress-program='pixz -p $(nproc) -5'"
}
export -f package_xz

function package_gz() {
  local input_dir="${1}"
  local output_basename="${2}"
  mkdir -p "$(dirname "${output_basename}")"
  nicely "find '${input_dir}' -printf '%P\\n' | tar --posix -cf '${output_basename}.tar.gz' -C '${input_dir}' --files-from=- --use-compress-program='pigz -p $(nproc) -7'"
}
export -f package_gz

function package_zst() {
  local input_dir="${1}"
  local output_basename="${2}"
  mkdir -p "$(dirname "${output_basename}")"
  nicely "find '${input_dir}' -printf '%P\\n' | tar --posix -cf '${output_basename}.tar.zst' -C '${input_dir}' --files-from=- --use-compress-program='zstdmt -q -T$(nproc) -7'"
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
