# 🏰 Castle of prebuilt static libraries for multiple platforms

## [Releases](https://github.com/binarylandia/staticbourg/releases)

## Build

```bash
./dev/cross/all zlib lzma bzip2 zstd
```

## What is this?

Cross-compiles common C libraries as static archives for Linux, macOS, and Windows. All libraries built with position-independent code (-fPIC) for embedding into applications or shared libraries.

## Features

- Static libraries with -fPIC for flexible linking
- Optimized builds (-O3, vectorization, loop unrolling)
- Architecture-tuned (Haswell for x86_64, ARMv8.2-a for aarch64 Linux, Apple M1 for aarch64 macOS)
- Multiple compression formats (xz, gzip, zstd)

## Use Cases

- Building fully static executables
- Embedding dependencies into Rust, Go, or Python native extensions
- Cross-platform CI/CD artifact creation
- Reproducible builds with pinned library versions

## Releases

Download from [GitHub Releases](https://github.com/binarylandia/staticbourg/releases).

## Keywords

static libraries, prebuilt static libs, cross compile static, zlib static, openssl static, bzip2 static, zstd static, lzma static, libffi static, libxml2 static, static linking, portable binaries
