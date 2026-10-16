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

## What is this?

Cross-compiles common C libraries as static archives for Linux, macOS, and Windows. All libraries built with position-independent code (-fPIC) for embedding into applications or shared libraries.

## Features

- Static libraries with -fPIC for flexible linking
- Optimized builds (-O3, vectorization, loop unrolling)
- Architecture-tuned (Haswell for x86_64, ARMv8.2-a for aarch64 Linux, Apple M1 for aarch64 macOS)
- Multiple compression formats (xz, gzip, zstd)
- WebAssembly archives of lzma and zstd for Emscripten, built with `emcc` and without threads. Emscripten has no ABI guarantee between versions, so these archives link only with the Emscripten version in their name (`wasm32-unknown-emscripten.6.0.10`), which `share/emscripten-version.txt` also records

## Use Cases

- Building fully static executables
- Embedding dependencies into Rust, Go, or Python native extensions
- Cross-platform CI/CD artifact creation
- Reproducible builds with pinned library versions

## Releases

Download from [GitHub Releases](https://github.com/binarylandia/staticbourg/releases).

## Keywords

static libraries, prebuilt static libs, cross compile static, zlib static, openssl static, bzip2 static, zstd static, lzma static, lzma wasm, zstd wasm, emscripten static libraries, libffi static, libxml2 static, static linking, portable binaries
