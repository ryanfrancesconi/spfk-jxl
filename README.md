# spfk-jxl

[![Version](https://img.shields.io/github/v/tag/ryanfrancesconi/spfk-jxl)](https://github.com/ryanfrancesconi/spfk-jxl/tags)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-jxl%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ryanfrancesconi/spfk-jxl)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-jxl%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ryanfrancesconi/spfk-jxl)

JPEG XL output for [spfk-image](https://github.com/ryanfrancesconi/spfk-image)'s image converter.
ImageIO reads JPEG XL but cannot write it, so this package vendors
[libjxl](https://github.com/libjxl/libjxl) and its dependencies (Highway, skcms, Brotli) as source
and supplies `JXLImageEncoder`, an encoder the converter accepts for that type. The C encoder API is
also available directly.

`JXLImageEncoder()` is `nil` on a system that does not declare the JPEG XL type, and the converter
offers JPEG XL only where ImageIO can read the result back, since it verifies each file it writes.

> **The root `LICENSE` (MIT) covers this packaging only — not libjxl, Highway, skcms or Brotli.**
See > [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) for their terms and the attribution an
embedding application owes.

## Upstream

The vendored sources are an unmodified upstream release; the build flags live in `Package.swift` and
compile libjxl optimized in every configuration, since it assumes an optimizing build.
`scripts/vendor-libjxl.sh` replaces them from a release-tag checkout and records the tag and the
pinned submodule commits in `upstream-versions.txt`.

## About

Spongefork is the personal software projects of musician and developer [Ryan Francesconi](https://spongefork.com). Dedicated to creative sound manipulation, his first application, Spongefork, was released in 1999 for macOS 8. From 2026, Spongefork returns as his software container for more musical experimentation. In addition to [software releases](https://spongefork.com/shadowtag/), open source components can be found on his [GitHub page](https://github.com/ryanfrancesconi).
