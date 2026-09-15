# spfk-jxl

[![Version](https://img.shields.io/github/v/tag/ryanfrancesconi/spfk-jxl)](https://github.com/ryanfrancesconi/spfk-jxl/tags)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-jxl%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ryanfrancesconi/spfk-jxl)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-jxl%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ryanfrancesconi/spfk-jxl)

JPEG XL output for [spfk-image](https://github.com/ryanfrancesconi/spfk-image)'s `ImageFormatConverter`, which
ImageIO reads but cannot write: [libjxl](https://github.com/libjxl/libjxl) and its dependencies vendored as source,
and an encoder over them.

> **The root `LICENSE` (MIT) covers this packaging only — not libjxl, Highway, skcms or Brotli.** See
> [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) for their terms and the attribution an embedding application owes.

## Features

- **`JXLImageEncoder`** — an `ImageFileEncoder` writing JPEG XL at the conversion's quality, lossless at quality 1,
  with the ICC profile, and EXIF and XMP in boxes. An image deeper than 8 bits per channel is written at 16.
- **`libjxl`** — the C encoder API (`jxl/encode.h`), for direct use. Its decoder and color management are compiled in
  because the encoder links against them.

## Usage

```swift
let encoders: [any ImageFileEncoder] = [JXLImageEncoder()].compactMap { $0 }
let formats = ImageConversionFormats(encoders: encoders)
let converted = try ImageFormatConverter(source: source, formats: formats).convert()
```

`JXLImageEncoder()` is `nil` on a system that does not declare `public.jpeg-xl`, and `ImageConversionFormats` offers
JPEG XL only where ImageIO can read it back, since the converter verifies each file it writes by reading it.

## Build

libjxl compiles as two SwiftPM targets: `libbrotli` in C, and `libjxl` in C++17 with Highway and skcms inside it.
The target uses one flag set, taken from libjxl's own CMake configuration, so the per-file flags CMake adds are not
applied: skcms's AVX2 and AVX-512 transforms on x86_64, and `-O3` on the fast lossless encoder. Both targets compile
with `-O2` in every configuration through `unsafeFlags`, which Xcode places after its own `-O0` or `-Os`. libjxl
assumes an optimizing build: unoptimized, an encode runs about 96× slower.

The encoder runs on libjxl's thread runner, one worker per core. Cancelling the task running `encode` stops it at
libjxl's next stage and throws `CancellationError`.

## Updating libjxl

`scripts/vendor-libjxl.sh <checkout> <cmake-build-dir>` replaces `Sources/libjxl/` and `Sources/libbrotli/` from a
libjxl checkout at a release tag with its submodules initialized, keeping only the headers the sources include. The
three headers CMake generates come from the configured build directory. It records the tag and the pinned submodule
commits in `upstream-versions.txt`. Re-read each license at the new versions before committing.

## Dependencies

| Package | Description |
|---------|-------------|
| [spfk-image](https://github.com/ryanfrancesconi/spfk-image) | `ImageFileEncoder` and the converter it plugs into |
| [spfk-base](https://github.com/ryanfrancesconi/spfk-base) | Test support |

## Requirements

- **Platforms:** macOS 13+
- **Swift:** 6.2+

## About

Spongefork is the personal software projects of musician and developer [Ryan Francesconi](https://spongefork.com). Dedicated to creative sound manipulation, his first application, Spongefork, was released in 1999 for macOS 8. From 2026, Spongefork returns as his software container for more musical experimentation. In addition to [software releases](https://spongefork.com/shadowtag/), open source components can be found on his [GitHub page](https://github.com/ryanfrancesconi).
