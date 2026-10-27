# 🏰 Castle of prebuilt static libraries for multiple platforms

## [Releases](https://github.com/binarylandia/staticbourg/releases)

## Build

```bash
./dev/cross/all zlib lzma bzip2 zstd
```

WebAssembly (`lzma` and `zstd` only):

```bash
./dev/cross/all --target=wasm32-unknown-emscripten lzma zstd
```

`--target=<triple>` selects targets, and `--serial` builds one target at a time. The archives go to `.out/<build time>/`; set `BUILD_TIME` to give several runs one build time.

## Release

One build of every task and target with one `BUILD_TIME`, then:

```bash
./dev/release --dry-run <build time>
./dev/release <build time>
```

`dev/release` checks that the archives are the full set (every task for every native target, and lzma and zstd for `wasm32-unknown-emscripten`, each in the three formats), that every archive comes from a clean build of `HEAD`, that a branch of `origin` (`binarylandia/staticbourg`) has `HEAD`, and that no release or other commit has the tag `<build time>`. Then it publishes the release `<build time>` with the archives, `SHA256SUMS`, and `manifest.json`.

## What is this?

Cross-compiles common C libraries as static archives for Linux, macOS, and Windows. All libraries built with position-independent code (-fPIC) for embedding into applications or shared libraries.

## Targets and toolchains

The toolchains are binarylandia releases, the same as in the [TreeTime](https://github.com/neherlab/treetime) builds that link the archives:

| Target | Compiler | C runtime | OS level | CPU baseline |
| --- | --- | --- | --- | --- |
| `x86_64-unknown-linux-gnu` | clang of LLVM 22.1.8 on the GCC 16.2.0 toolchain | glibc 2.17 | | `-march=x86-64-v2` |
| `aarch64-unknown-linux-gnu` | clang of LLVM 22.1.8 on the GCC 16.2.0 toolchain | glibc 2.17 | | `-march=armv8-a -moutline-atomics` |
| `x86_64-unknown-linux-musl` | clang of LLVM 22.1.8 on the GCC 16.2.0 toolchain | musl 1.2.6 | | `-march=x86-64-v2` |
| `aarch64-unknown-linux-musl` | clang of LLVM 22.1.8 on the GCC 16.2.0 toolchain | musl 1.2.6 | | `-march=armv8-a -moutline-atomics` |
| `x86_64-apple-darwin` | osxcross (macOS 11.1 SDK) on LLVM 22.1.8 | | macOS 10.12 | `-march=x86-64-v2` |
| `aarch64-apple-darwin` | osxcross (macOS 11.1 SDK) on LLVM 22.1.8 | | macOS 11.0 | `-mcpu=apple-m1` |
| `x86_64-pc-windows-gnullvm` | llvm-mingw 22.1.8 | UCRT | | `-march=x86-64-v2` |
| `aarch64-pc-windows-gnullvm` | llvm-mingw 22.1.8 | UCRT | | `-march=armv8-a+lse` |
| `x86_64-pc-windows-gnu` | MinGW GCC 16.2.0 | msvcrt | Windows 7 (`_WIN32_WINNT=0x0601`) | `-march=x86-64-v2` |
| `wasm32-unknown-emscripten` | Emscripten 6.0.13 | | | |

The toolchain archives are pinned with their sha256 in `dev/docker/files/`. The x86_64 and arm64 Linux baselines let the archives run on every CPU that their consumers support: x86-64-v2 has no AVX, and Armv8.0 runs on Cortex-A53 and Cortex-A72 cores, with LSE atomics through the outline atomics helpers where the CPU has them. Windows on Arm requires LSE, and the Windows targets have no outline atomics helpers.

## Build records

Each archive contains `share/staticbourg/build.json`, and the release carries the same record per archive in `manifest.json`:

- `name`, `task`, `library`, `version`, `source`, `source_sha256`: the archive, the task (`tasks/<task>/build`), and the library with its source tarball
- `kind`: `native`, or `wasm`
- `target`, `compiler`: the target, and the first line of `$CC --version`
- `llvm`: the `binarylandia/build_llvm` release of the build image (native targets)
- `target_toolchain`: `url` and `sha256` of the GCC, osxcross, llvm-mingw, or Emscripten archive of the target
- `cflags`: the C flags that the task passes to the build of the library, which the build system of the library can extend
- `cpu_flags`: the CPU baseline flags among them (native targets)
- `macosx_deployment_target`, `win32_winnt`: the macOS deployment target, and the `_WIN32_WINNT` value of `x86_64-pc-windows-gnu`
- `emscripten`: the Emscripten version (wasm)
- `dockerfile`, `dockerfile_sha256`, `build_commit`, `build_dirty`, `build_time`: the build image file, the commit of this repository, whether the checkout had uncommitted or untracked files, and the build time
- `files`: the archive files

## OpenSSL paths

OpenSSL finds its configuration file and the default trust store (`cert.pem` and `certs/`) in a folder that is compiled into libcrypto:

- **Linux and macOS**: `/etc/ssl`, where Debian, Ubuntu, Alpine, Arch, openSUSE, and macOS keep their trust store. On other systems, set `SSL_CERT_FILE` or `SSL_CERT_DIR`, or load the CA certificates in the program
- **Windows**: the folder that the registry value `HKLM\SOFTWARE\WOW6432Node\OpenSSL-3.5-binarylandia\OPENSSLDIR` names (`OSSL_WINCTX`), which only administrators can write. Without the value, OpenSSL loads no configuration file and trusts no default store, so programs load their CA certificates themselves. A folder compiled into the library would let any user plant a configuration or a CA certificate, because users can create folders such as `C:\etc\ssl`

## Features

- Static libraries with -fPIC for flexible linking
- Optimized builds (-O3, vectorization, loop unrolling)
- Sources downloaded from the upstream releases and verified by sha256 (`tasks/<name>/checksums`)
- Multiple compression formats (xz, gzip, zstd)
- WebAssembly archives of lzma and zstd for Emscripten, built with `emcc` and without threads. Emscripten has no ABI guarantee between versions, so these archives link only with the Emscripten version in their name (`wasm32-unknown-emscripten.6.0.13`), which `share/emscripten-version.txt` also records

## Use Cases

- Building fully static executables
- Embedding dependencies into Rust, Go, or Python native extensions
- Cross-platform CI/CD artifact creation
- Reproducible builds with pinned library versions

## Releases

Download from [GitHub Releases](https://github.com/binarylandia/staticbourg/releases).

## Keywords

static libraries, prebuilt static libs, cross compile static, zlib static, openssl static, bzip2 static, zstd static, lzma static, lzma wasm, zstd wasm, emscripten static libraries, libffi static, libxml2 static, static linking, portable binaries
